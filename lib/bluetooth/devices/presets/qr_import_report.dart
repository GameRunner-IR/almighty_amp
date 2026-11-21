import 'package:qr_utils/qr_utils.dart';

class QrImportWarning {
  final String category; // e.g. Mod, Delay, Reverb, Amp
  final String name;
  final Map<String, String> parameters;

  const QrImportWarning({
    required this.category,
    required this.name,
    this.parameters = const {},
  });
}

class QrImportReport {
  final PresetQRError error;
  final List<QrImportWarning> warnings;

  const QrImportReport(this.error, [this.warnings = const []]);

  bool get isOk => error == PresetQRError.Ok;

  static const ok = QrImportReport(PresetQRError.Ok);
}
