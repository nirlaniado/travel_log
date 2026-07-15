"""add login lockout state

Revision ID: 0002
Revises: 0001
Create Date: 2026-07-09

"""
import sqlalchemy as sa

from alembic import op

revision = "0002"
down_revision = "0001"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "users",
        sa.Column("failed_login_count", sa.SmallInteger(), server_default="0", nullable=False),
    )
    op.add_column("users", sa.Column("failed_login_first_at", sa.DateTime(), nullable=True))
    op.add_column("users", sa.Column("locked_until", sa.DateTime(), nullable=True))


def downgrade() -> None:
    op.drop_column("users", "locked_until")
    op.drop_column("users", "failed_login_first_at")
    op.drop_column("users", "failed_login_count")
