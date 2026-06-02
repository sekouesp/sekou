import 'dart:js_interop';

@JS('initOneSignalWeb')
external void _initOneSignalWeb(JSString appId);

@JS('loginOneSignalWeb')
external void _loginOneSignalWeb(JSString uid, JSString? dept);

@JS('logoutOneSignalWeb')
external void _logoutOneSignalWeb();

void initOneSignalWeb(String appId) {
  _initOneSignalWeb(appId.toJS);
}

void loginOneSignalWeb(String uid, String? dept) {
  _loginOneSignalWeb(uid.toJS, dept?.toJS);
}

void logoutOneSignalWeb() {
  _logoutOneSignalWeb();
}
