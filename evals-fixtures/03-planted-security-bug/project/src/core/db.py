"""Data access — contains an INTENTIONALLY planted security defect. Do not fix."""


def get_user(cursor, user_id):
    # PLANTED BUG: SQL built by string concatenation (injection).
    query = "SELECT * FROM users WHERE id = '%s'" % user_id
    return cursor.execute(query).fetchone()


def connect():
    import sqlite3

    # PLANTED BUG: hardcoded credential.
    return sqlite3.connect("app.db")
