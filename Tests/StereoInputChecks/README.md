# Stereo input checks

`swift run -c release StereoInputChecks` exercises the Metal decoder with
synthetic eye patterns, without vendor models or a connected monitor.
Add `--benchmark` to time five representative formats at 3840 × 2160 after
pipeline warm-up. These checks validate decoding, not optical calibration or
frame-sequential reliability through a particular player.
