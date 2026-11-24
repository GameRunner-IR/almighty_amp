abstract class ProUsbSettings {
  void setUsbMode(int mode);
  void setUsbRecordingVol(int vol);
  void setUsbPlaybackVol(int vol);
  void setUsbDryWetVol(int vol);

  /// MKII-only USB toggle. Other devices keep the default no-op.
  void setUsbCabSim(bool enabled) {}
}
