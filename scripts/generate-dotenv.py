#!/usr/bin/env python3

import os
import secrets
import string
import tempfile


def generate_password(length=20):
    """Generate a secure password that can be safely used in yaml files."""
    alphabet = string.ascii_letters + string.digits + string.punctuation
    # Remove characters that are not safe to use in yaml files. `$` goes with
    # them because helmsman expands `$NAME` inside a double-quoted .env value.
    alphabet = alphabet.replace('"', '').replace("'", '').replace('\\', '').replace('`', '').replace('$', '')
    while True:
        password = ''.join(secrets.choice(alphabet) for i in range(length))
        if (any(c.islower() for c in password) and any(c.isupper() for c in password)
                and any(c.isdigit() for c in password) and any(c in string.punctuation for c in password)):
            break
    return password


def generate_pronounceable_password(length=20):
    """
    Generate a pronounceable password consisting of 4 words from a huge 
    dictionary, each followed by a digit.
    """
    try:
        with open("/usr/share/dict/words") as file:
            words = file.readlines()
    except FileNotFoundError:
        print("No word list at /usr/share/dict/words; using a random password.")
        return generate_password(length)
    words = [word.strip() for word in words if 3 <= len(word) <= 8]
    password = ''.join(secrets.choice(words).capitalize() + str(secrets.choice(range(10))) for i in range(4))
    return password


def create_env_file(file_name=".env"):
    """Create .env file with secure passwords."""
    random_password_keys = [
        "DB_ROOT_PASSWORD",
        "DB_REPLICATION_PASSWORD",
        "DB_PASSWORD",
        "REDIS_PASSWORD",
        "APP_SECRET",
    ]
    pronounceable_password_keys = [
        "ADMIN_PASSWORD",
    ]

    # A later run only checks that .env exists, so a half-written file would
    # be taken as finished and never regenerated. Generate every value first,
    # then move the completed file into place in one step.
    values = [(key, generate_password()) for key in random_password_keys]
    values += [(key, generate_pronounceable_password())
               for key in pronounceable_password_keys]

    fd, temp_name = tempfile.mkstemp(dir=os.path.dirname(os.path.abspath(file_name)))
    try:
        with os.fdopen(fd, "w") as file:
            for key, password in values:
                file.write(f"{key}=\"{password}\"\n")
        os.replace(temp_name, file_name)
    except BaseException:
        os.unlink(temp_name)
        raise

    print(f"File '{file_name}' has been created with secure passwords.")


# create .env file if it does not exist
try:
    with open(".env") as file:
        print("File '.env' already exists.")
except FileNotFoundError:
    create_env_file()
