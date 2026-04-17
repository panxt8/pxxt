class SignTypeInfo {
  const SignTypeInfo({
    required this.activeId,
    required this.otherId,
    required this.ifPhoto,
  });

  final String activeId;
  final String otherId;
  final String ifPhoto;

  bool get isPhotoSign => otherId == '0' && ifPhoto == '1';
  bool get isQrCodeSign => otherId == '2';
  bool get isGestureSign => otherId == '3';
  bool get isLocationSign => otherId == '4';
  bool get isCodeSign => otherId == '5';
}
