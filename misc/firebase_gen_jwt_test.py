import firebase_admin
from firebase_admin import auth
default_app = firebase_admin.initialize_app()
uid = 'XB16TASkHORCIrLapCP2LZDp04s1'

custom_claims = { "admin": False, "debug": False, "d": {"cj_id": "bekk","cjpasscode": "f2bbae54f0d9717511c49cf77e4d2a22"}}

custom_token = auth.create_custom_token(uid, custom_claims)

print(custom_token)
