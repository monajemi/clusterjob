import firebase_admin
from firebase_admin import auth
default_app = firebase_admin.initialize_app()
uid = 'test'

custom_claims = { "admin": False, "debug": False, "d": {"cj_id": "test","cjpasscode": "test"}}
auth.set_custom_user_claims(uid, {'test': True})

custom_token = auth.create_custom_token(uid, custom_claims)

print(custom_token)
