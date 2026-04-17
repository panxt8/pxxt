class AppUrls {
  static String login(String username, String password) =>
      'https://passport2-api.chaoxing.com/v11/loginregister?code=$password&cx_xxt_passport=json&uname=$username&loginType=1&roleSelect=true';

  static String allCourses() =>
      'http://mooc1-api.chaoxing.com/mycourse/backclazzdata';

  static String userInfo() => 'http://i.chaoxing.com/base';

  static String avatar(String uid) => 'https://photo.chaoxing.com/p/${uid}_80';

  static String activeTaskList(
    String courseId,
    String classId,
    String uid,
    String cpi,
  ) =>
      'https://mobilelearn.chaoxing.com/ppt/activeAPI/taskactivelist?courseId=$courseId&classId=$classId&uid=$uid&cpi=$cpi';

  static String signType(String activeId) =>
      'https://mobilelearn.chaoxing.com/newsign/signDetail?activePrimaryId=$activeId&type=1';

  static String pptActiveInfo(String activeId) =>
      'https://mobilelearn.chaoxing.com/v2/apis/active/getPPTActiveInfo?activeId=$activeId';

  static String signWithCamera(
    String aid,
    String location, {
    String validate = '',
  }) =>
      'https://mobilelearn.chaoxing.com/pptSign/stuSignajax?activeId=$aid&location=$location&validate=$validate';

  static String signWithCameraNoLocation(String aid, {String validate = ''}) =>
      'https://mobilelearn.chaoxing.com/pptSign/stuSignajax?activeId=$aid&validate=$validate';

  static String normalSign(
    String courseId,
    String classId,
    String aid, {
    String signCode = '',
    String validate = '',
  }) =>
      'https://mobilelearn.chaoxing.com/widget/sign/pcStuSignController/signIn?courseId=$courseId&classId=$classId&activeId=$aid&signCode=$signCode&validate=$validate';

  static String analysis(String aid) =>
      'https://mobilelearn.chaoxing.com/pptSign/analysis?DB_STRATEGY=RANDOM&aid=$aid&vs=1';

  static String analysis2(String code) =>
      'https://mobilelearn.chaoxing.com/pptSign/analysis2?DB_STRATEGY=RANDOM&code=$code';

  static String checkSignCode(String aid, String signCode) =>
      'https://mobilelearn.chaoxing.com/widget/sign/pcStuSignController/checkSignCode?activeId=$aid&signCode=$signCode';

  static String uploadToken() =>
      'https://pan-yz.chaoxing.com/api/token/uservalid';

  static String uploadImage(String token) =>
      'https://pan-yz.chaoxing.com/upload?_token=$token';

  static String photoSign(
    String aid,
    String uid,
    String objectId, {
    String validate = '',
  }) =>
      'https://mobilelearn.chaoxing.com/pptSign/stuSignajax?activeId=$aid&uid=$uid&appType=15&fid=0&objectId=$objectId&validate=$validate';

  static String locationSign({
    required String address,
    required String aid,
    required String uid,
    required String latitude,
    required String longitude,
    required String fid,
    String validate = '',
  }) =>
      'https://mobilelearn.chaoxing.com/pptSign/stuSignajax?address=$address&activeId=$aid&uid=$uid&clientip=0.0.0.0&latitude=$latitude&longitude=$longitude&fid=$fid&appType=15&ifTiJiao=1&validate=$validate';
}
