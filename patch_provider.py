import os
import certifi

path = r'C:\Users\daniy\OneDrive\Desktop\FYP Project\fish_fresh_app\lib\data\repositories\app_provider.dart'

with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

new_logic = '''
  String _userId = '';
  String get userId => _userId;
  
  String _userName = '';
  String get userName => _userName;
  
  bool get isLoggedIn => _userId.isNotEmpty;

  Future<String?> register(String email, String password, String name) async {
    final res = await _apiService.registerUser(email, password, name);
    if (res['success'] == true) {
      _userId = res['user_id'];
      _userName = res['name'];
      _apiService.setUserId(_userId);
      await refreshData();
      return null;
    }
    return res['error'];
  }

  Future<String?> login(String email, String password) async {
    final res = await _apiService.loginUser(email, password);
    if (res['success'] == true) {
      _userId = res['user_id'];
      _userName = res['name'];
      _apiService.setUserId(_userId);
      await refreshData();
      return null;
    }
    return res['error'];
  }

  void logout() {
    _userId = '';
    _userName = '';
    _apiService.setUserId('default_user');
    _scanHistory = [];
    _subscription = null;
    notifyListeners();
  }
'''

if "Future<String?> login" not in content:
    # replace the simulateLogin part
    import re
    content = re.sub(r'String _userId = \'default_user\';\s*String get userId => _userId;\s*void simulateLogin\(String newUserId\) \{[^\}]+\}', new_logic, content)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
