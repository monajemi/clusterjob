// Requires: composer require firebase/php-jwt
require __DIR__ . '/vendor/autoload.php';

// Get your service account's email address and private key from the JSON key file
$service_account_email = "";
$private_key = "';

use Firebase\JWT\JWT;
function create_custom_token($cj_id, $cjpasscode) {
  global $service_account_email, $private_key, $uid;

  $now_seconds = time();
  $payload = array(
    "iss" => $service_account_email,
    "sub" => $service_account_email,
    "aud" => "https://identitytoolkit.googleapis.com/google.identity.identitytoolkit.v1.IdentityToolkit",
    "iat" => $now_seconds,
    "exp" => $now_seconds+(60*60),
    "uid" => $uid,
    "claims" => array(
      "admin" => 0,
      "debug" => 0,
      "d" => array(
          "cj_id" => $cj_id,
          "cjpasscode" => $cjpasscode
        )
      )
    );
  return JWT::encode($payload, $private_key, "RS256");
}

create_custom_token("bekk", "");
