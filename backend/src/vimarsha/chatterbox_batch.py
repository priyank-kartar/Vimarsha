"""Batched Chatterbox narration via the petermg Chatterbox-TTS-Extended fork's ``generate_batch``.

The fork's batched path ships with three bugs that we patch at load (validated on RunPod A40,
2026-06-21 — ~3.4x faster than sequential on a full chapter, audio indistinguishable from single):

1. ``inference_batch`` builds the CFG batch *stacked* (``cat([text, text])`` = all-cond then
   all-uncond) but ``_sample_loop`` and the per-step logic are *interleaved* (``[0::2]``=cond,
   ``[1::2]``=uncond) — so cond/uncond rows are mismatched from token 0.
2. The text-token tensor carries a spurious size-1 dim (4D embeddings) → a 2D-vs-3D cat crash.
3. Batched decode pads finished sequences with EOS, so each item has *many* EOS tokens;
   ``drop_invalid_tokens`` does ``.squeeze(0)`` expecting exactly one → multi-element index crash.

``apply_batch_patches`` fixes all three WITHOUT touching the single-``generate()`` path (it only
replaces ``inference_batch`` — unused by single — and makes ``drop_invalid_tokens`` take the FIRST
SOS/EOS, which is identical to the original when there's exactly one match).

The fork is overlaid over the pip-installed ``chatterbox`` in the worker image (see
``Dockerfile.serverless``); everything here is lazily imported so the rest of the package — and
local/dev installs without the fork — run unaffected.
"""
from __future__ import annotations

import numpy as np

_patched = False


def apply_batch_patches(model) -> None:
    """Idempotently fix the fork's batched path on the loaded model's classes."""
    global _patched
    if _patched:
        return
    import torch
    from chatterbox.models.t3 import t3 as t3_mod

    T3 = type(model.t3)

    @torch.inference_mode()
    def inference_batch(self, *, t3_cond, text_tokens, initial_speech_tokens=None,
                        max_new_tokens=1000, temperature=0.8, top_p=0.8,
                        repetition_penalty=2.0, cfg_weight=0.0, generator=None):
        t3_mod._ensure_BOT_EOT(text_tokens, self.hp)
        text_tokens = torch.atleast_2d(text_tokens).to(dtype=torch.long, device=self.device)
        if text_tokens.dim() == 3:
            text_tokens = text_tokens.squeeze(1)             # (B,1,Lt) -> (B,Lt)
        B = text_tokens.size(0)
        if initial_speech_tokens is None:
            initial_speech_tokens = self.hp.start_speech_token * torch.ones(
                (B, 1), dtype=torch.long, device=self.device)
        sp = torch.atleast_2d(initial_speech_tokens)
        if sp.dim() == 3:
            sp = sp.squeeze(1)
        use_cfg = cfg_weight > 0.0
        if use_cfg:                                          # INTERLEAVED (matches _sample_loop)
            tt = torch.repeat_interleave(text_tokens, 2, dim=0)
            st = torch.repeat_interleave(sp, 2, dim=0)
        else:
            tt, st = text_tokens, sp
        cond_emb = self.prepare_conditioning(t3_cond)
        text_emb = self.text_emb(tt)
        speech_emb = self.speech_emb(st)
        if self.hp.input_pos_emb == "learned":
            text_emb = text_emb + self.text_pos_emb(tt)
            speech_emb = speech_emb + self.speech_pos_emb(st)
        if use_cfg:
            text_emb[1::2] = 0.0                             # zero uncond text (odd rows)
            cond_emb = cond_emb.repeat_interleave(2, dim=0)  # match interleaved rows
        elif cond_emb.size(0) == 1 and text_emb.size(0) > 1:
            cond_emb = cond_emb.expand(text_emb.size(0), -1, -1)
        embeds, _ = self._pad_stack_embeds(cond_emb, text_emb, speech_emb)
        if not self.compiled:
            self.patched_model = t3_mod.T3HuggingfaceBackend(
                config=self.cfg, llama=self.tfmr, speech_enc=self.speech_emb,
                speech_head=self.speech_head)
            self.compiled = True
        bos_token = torch.tensor([[self.hp.start_speech_token]], dtype=torch.long, device=embeds.device)
        bos_embed = self.speech_emb(bos_token) + self.speech_pos_emb.get_fixed_embedding(0)
        inputs_embeds = torch.cat([embeds, bos_embed.expand(embeds.size(0), -1, -1)], dim=1)
        return self._sample_loop(
            inputs_embeds=inputs_embeds, cfg_weight=cfg_weight, max_new_tokens=max_new_tokens,
            temperature=temperature, top_p=top_p, repetition_penalty=repetition_penalty,
            generator=generator, cond_batch=B, stop_id=self.hp.stop_speech_token)

    T3.inference_batch = inference_batch

    import chatterbox.tts as tts_mod
    from chatterbox.models import s3tokenizer as s3_mod
    sos, eos = s3_mod.SOS, s3_mod.EOS

    def drop_invalid_tokens(x):
        s = int((x == sos).nonzero(as_tuple=True)[0][0]) + 1 if (sos in x) else 0
        e = int((x == eos).nonzero(as_tuple=True)[0][0]) if (eos in x) else None
        return x[s:e]

    tts_mod.drop_invalid_tokens = drop_invalid_tokens
    _patched = True


class ChatterboxBatchSynth:
    """``BatchSynthesizer`` over the patched fork. CUDA worker only; constructed lazily.

    Premium voices map to ``(exaggeration, cfg_weight)`` presets (see ``chatterbox_preset``).
    """

    def __init__(self, voice: str | None = None, device: str | None = None,
                 audio_prompt_path: str | None = None):
        import torch
        from chatterbox.tts import ChatterboxTTS

        from vimarsha.tts import chatterbox_preset

        if device is None:
            device = "cuda" if torch.cuda.is_available() else "cpu"
        self._model = ChatterboxTTS.from_pretrained(device=device)
        apply_batch_patches(self._model)
        self._device = device
        self.sample_rate = self._model.sr
        self._kwargs = chatterbox_preset(voice)
        if audio_prompt_path:
            self._kwargs["audio_prompt_path"] = audio_prompt_path

    def synthesize_batch(self, texts: list[str]) -> list[np.ndarray]:
        import torch

        if not texts:
            return []
        outs = self._model.generate_batch(list(texts), **self._kwargs)
        result = [
            (w.squeeze(0) if hasattr(w, "dim") and w.dim() > 1 else w)
            .detach().cpu().numpy().astype("float32")
            for w in outs
        ]
        # Keep peak memory flat across a long chapter (the allocator caches per-batch tensors).
        del outs
        if self._device == "cuda":
            torch.cuda.empty_cache()
        return result
