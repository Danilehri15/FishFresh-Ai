import os

path = r'C:\Users\daniy\OneDrive\Desktop\FYP Project\fish_fresh_app\lib\data\services\api_service.dart'

with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

new_methods = '''
  Future<Map<String, dynamic>> registerUser(String email, String password, String name) async {
    try {
      final uri = Uri.parse('\/api/auth/register');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password, 'name': name}),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {'success': false, 'error': jsonDecode(response.body)['detail']};
      }
    } catch (e) {
      return {'success': false, 'error': 'Connection error'};
    }
  }

  Future<Map<String, dynamic>> loginUser(String email, String password) async {
    try {
      final uri = Uri.parse('\/api/auth/login');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {'success': false, 'error': jsonDecode(response.body)['detail']};
      }
    } catch (e) {
      return {'success': false, 'error': 'Connection error'};
    }
  }
'''

if "Future<Map<String, dynamic>> registerUser" in content:
    idx = content.find("Future<Map<String, dynamic>> registerUser")
    content = content[:idx].strip()
    
last_brace = content.rfind("}")
if last_brace != -1:
    content = content[:last_brace] + new_methods + "\n}\n"

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)

account_path = r'C:\Users\daniy\OneDrive\Desktop\FYP Project\fish_fresh_app\lib\ui\features\account\account_view.dart'
with open(account_path, 'r', encoding='utf-8') as f:
    acc = f.read()

acc = acc.replace(r"\$" + "{score", "$" + "{score")
with open(account_path, 'w', encoding='utf-8') as f:
    f.write(acc)

