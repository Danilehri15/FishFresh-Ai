import os

path = r'C:\Users\daniy\OneDrive\Desktop\FYP Project\backend\app.py'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

auth_models = '''
class RegisterRequest(BaseModel):
    email: str
    password: str
    name: str

class LoginRequest(BaseModel):
    email: str
    password: str
'''
if "class RegisterRequest" not in content:
    content = content.replace('class ChatRequest(BaseModel):', auth_models + '\nclass ChatRequest(BaseModel):')

auth_endpoints = '''
@app.post("/api/auth/register")
def register(payload: RegisterRequest):
    res = cloud_db.register_user(payload.email, payload.password, payload.name)
    if res.get("success"):
        return res
    raise HTTPException(status_code=400, detail=res.get("error", "Unknown error"))

@app.post("/api/auth/login")
def login(payload: LoginRequest):
    res = cloud_db.login_user(payload.email, payload.password)
    if res.get("success"):
        return res
    raise HTTPException(status_code=401, detail=res.get("error", "Invalid credentials"))
'''
if "@app.post(\"/api/auth/register\")" not in content:
    content = content + '\n' + auth_endpoints

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
