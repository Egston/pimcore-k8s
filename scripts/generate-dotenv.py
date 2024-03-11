#!/bin/env python3

import secrets
import string


def generate_password(length=20):
    """Generate password that can be used in yaml, shell env. variables and CLI argument without escaping."""
    alphabet = string.ascii_letters + string.digits + '-_@: ;,./?~!#%^&*()[]{}<>|'
    while True:
        password = ''.join(secrets.choice(alphabet) for i in range(length))
        if (any(c.islower() for c in password) and any(c.isupper() for c in password)
                and any(c.isdigit() for c in password) and any(c in string.punctuation for c in password)):
            break
    return password


def generate_password(length=20):
    """Generate a secure password that can be safely used in yaml files."""
    alphabet = string.ascii_letters + string.digits + string.punctuation
    # Remove characters that are not safe to use in yaml files
    alphabet = alphabet.replace('"', '').replace("'", '').replace('\\', '').replace('`', '')
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
    with open("/usr/share/dict/words") as file:
        words = file.readlines()
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

    with open(file_name, "w") as file:
        import os
        os.chmod(file_name, 0o600)

        for key in random_password_keys:
            password = generate_password()
            file.write(f"{key}=\"{password}\"\n")
        for key in pronounceable_password_keys:
            password = generate_pronounceable_password()
            file.write(f"{key}=\"{password}\"\n")

    print(f"File '{file_name}' has been created with secure passwords.")


# create .env file if it does not exist
try:
    with open(".env") as file:
        print("File '.env' already exists.")
except FileNotFoundError:
    create_env_file()
