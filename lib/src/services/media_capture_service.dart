import 'package:image_picker/image_picker.dart';

class MediaCaptureService {
  MediaCaptureService({ImagePicker? imagePicker})
    : _imagePicker = imagePicker ?? ImagePicker();

  final ImagePicker _imagePicker;

  Future<String?> pickMealImageFromGallery() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    return image?.path;
  }

  Future<String?> pickMealImageFromCamera() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    return image?.path;
  }
}
