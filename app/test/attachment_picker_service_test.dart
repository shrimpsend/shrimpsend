import 'package:app/services/attachment_picker_service.dart';
import 'package:app/utils/runtime_platform.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('imageVideoUsesDesktopFilePicker matches RuntimePlatform.isDesktop', () {
    expect(
      AttachmentPickerService.imageVideoUsesDesktopFilePicker,
      RuntimePlatform.isDesktop,
    );
  });
}
