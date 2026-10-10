#!/usr/bin/env python3
"""Build-time FP16 Core ML export of bundled Video Depth Anything Small.

Adapted from Video-Depth-Anything, Copyright (2025) Bytedance Ltd. and/or its
 affiliates, Apache-2.0. See Resources/Licenses/Video-Depth-Anything-LICENSE.txt.
Python and export dependencies are needed only by developers, never app users.
"""
import argparse
import hashlib
import pathlib
import shutil
import subprocess
import sys
import types

import coremltools as ct
import numpy as np
import torch
from safetensors.torch import load_file

REVISION = "4f5ae23172ba60fd7bc11ef671cca678842c7072"
WEIGHTS_SHA = "85c583474dcafda4d417776431343afcdfdfc97952d8ec00029d3452c55a05a2"


class Wrapper(torch.nn.Module):
    def __init__(self, model):
        super().__init__()
        self.model = model

    def forward(self, image, *cache):
        features = self.model.forward_features(image)
        depth, new = self.model.forward_depth(
            features, image.shape, cached_hidden_state_list=list(cache) if cache else None
        )
        return (depth, *new)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--upstream", required=True, type=pathlib.Path)
    parser.add_argument("--weights", required=True, type=pathlib.Path)
    parser.add_argument("--scratch", required=True, type=pathlib.Path)
    parser.add_argument("--output", required=True, type=pathlib.Path)
    args = parser.parse_args()
    revision = subprocess.check_output(["git", "-C", str(args.upstream), "rev-parse", "HEAD"], text=True).strip()
    if revision != REVISION or hashlib.sha256(args.weights.read_bytes()).hexdigest() != WEIGHTS_SHA:
        raise RuntimeError("Use the pinned upstream revision and Small checkpoint")
    sys.path.insert(0, str(args.upstream.resolve()))
    from video_depth_anything.video_depth_stream import VideoDepthAnything

    args.scratch.mkdir(parents=True, exist_ok=True)
    args.output.mkdir(parents=True, exist_ok=True)
    torch.set_num_threads(4)
    model = VideoDepthAnything(encoder="vits", features=64, out_channels=[48, 96, 192, 384]).eval()
    model.load_state_dict(load_file(str(args.weights)))
    image = torch.zeros(1, 1, 3, 294, 518)
    wrapper = Wrapper(model).eval()
    with torch.no_grad():
        reference = wrapper(image)
        # The input dimensions are fixed. Precompute exactly the upstream bicubic
        # position embedding; Core ML cannot convert upsample_bicubic2d. This
        # also removes that resize from every video frame without approximating it.
        position = model.pretrained.interpolate_pos_encoding(torch.zeros(1, 778, 384), 294, 518)
        model.pretrained.register_buffer("fixed_position", position)
        model.pretrained.interpolate_pos_encoding = types.MethodType(
            lambda self, x, w, h: self.fixed_position.to(x.dtype), model.pretrained
        )
        initial = wrapper(image)
        for before, after in zip(reference, initial):
            torch.testing.assert_close(before, after, rtol=0, atol=0)
        for recurrent in [False, True]:
            arguments = (image, *[x.repeat(1, 31, 1) for x in initial[1:]]) if recurrent else (image,)
            phase = "stream" if recurrent else "first"
            traced = torch.jit.trace(wrapper, arguments, check_trace=False)
            inputs = [ct.TensorType(name="image", shape=image.shape, dtype=np.float32)]
            if recurrent:
                inputs += [ct.TensorType(name=f"history{i}", shape=x.shape, dtype=np.float16)
                           for i, x in enumerate(arguments[1:])]
            outputs = [ct.TensorType(name="depth", dtype=np.float32)] + [
                ct.TensorType(name=f"cache{i}", dtype=np.float16) for i in range(8)]
            converted = ct.convert(
                traced, inputs=inputs, outputs=outputs, convert_to="mlprogram",
                minimum_deployment_target=ct.target.macOS14,
                compute_precision=ct.precision.FLOAT16,
                compute_units=ct.ComputeUnit.CPU_AND_GPU, skip_model_load=True)
            converted.author = "Bytedance Ltd. and/or its affiliates; macdissey 3d Core ML adaptation"
            converted.license = "Apache-2.0"
            converted.short_description = f"Video Depth Anything Small, 518×294, {phase}, FP16"
            converted.user_defined_metadata["upstream_revision"] = REVISION
            converted.user_defined_metadata["checkpoint_sha256"] = WEIGHTS_SHA
            package = args.scratch / f"{phase}.mlpackage"
            converted.save(str(package))
            compiled = pathlib.Path(ct.models.utils.compile_model(str(package)))
            try:
                destination = args.output / f"{phase}.mlmodelc"
                if destination.exists(): shutil.rmtree(destination)
                shutil.copytree(compiled, destination)
            finally: shutil.rmtree(compiled)
            print("Compiled", destination, flush=True)


if __name__ == "__main__":
    main()
