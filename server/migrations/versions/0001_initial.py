"""Initial control model."""
from alembic import op
import sqlalchemy as sa

revision = "0001"
down_revision = None
branch_labels = None
depends_on = None


def upgrade():
    op.create_table("scene", sa.Column("id", sa.Integer, primary_key=True),
                    sa.Column("generation", sa.Integer, nullable=False), sa.Column("tick", sa.Integer, nullable=False),
                    sa.Column("paused", sa.Boolean, nullable=False), sa.Column("data", sa.JSON, nullable=False))
    op.create_table("members", sa.Column("id", sa.String(36), primary_key=True),
                    sa.Column("username", sa.String(64), unique=True, nullable=False),
                    sa.Column("password_hash", sa.Text, nullable=False), sa.Column("role", sa.String(16), nullable=False),
                    sa.Column("enabled", sa.Boolean, nullable=False))
    op.create_table("sessions", sa.Column("token_hash", sa.String(64), primary_key=True),
                    sa.Column("user_id", sa.String(36), nullable=False), sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False))
    op.create_index("ix_sessions_user_id", "sessions", ["user_id"])
    op.create_table("links", sa.Column("id", sa.String(36), primary_key=True),
                    sa.Column("user_id", sa.String(36), nullable=False), sa.Column("session_hash", sa.String(64), nullable=False),
                    sa.Column("node_id", sa.String(36), nullable=False), sa.Column("generation", sa.Integer, nullable=False),
                    sa.Column("last_used", sa.DateTime(timezone=True), nullable=False), sa.Column("revoked", sa.Boolean, nullable=False))
    op.create_index("ix_links_user_id", "links", ["user_id"])
    op.create_index("ix_links_session_hash", "links", ["session_hash"])
    op.create_table("scans", sa.Column("id", sa.String(36), primary_key=True),
                    sa.Column("user_id", sa.String(36), nullable=False), sa.Column("session_hash", sa.String(64), nullable=False),
                    sa.Column("node_id", sa.String(36), nullable=False), sa.Column("generation", sa.Integer, nullable=False),
                    sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False))
    op.create_table("confirmations", sa.Column("id", sa.String(36), primary_key=True),
                    sa.Column("user_id", sa.String(36), nullable=False), sa.Column("link_id", sa.String(36), nullable=False),
                    sa.Column("generation", sa.Integer, nullable=False), sa.Column("request", sa.JSON, nullable=False),
                    sa.Column("versions", sa.JSON, nullable=False), sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
                    sa.Column("used", sa.Boolean, nullable=False))
    op.create_table("commands", sa.Column("id", sa.String(36), primary_key=True),
                    sa.Column("user_id", sa.String(36), nullable=False), sa.Column("key", sa.String(64), nullable=False),
                    sa.Column("request", sa.JSON, nullable=False), sa.Column("result", sa.JSON, nullable=False),
                    sa.Column("created_at", sa.DateTime(timezone=True), nullable=False), sa.UniqueConstraint("user_id", "key"))
    op.create_index("ix_commands_user_id", "commands", ["user_id"])
    op.create_table("events", sa.Column("id", sa.Integer, primary_key=True, autoincrement=True),
                    sa.Column("created_at", sa.DateTime(timezone=True), nullable=False), sa.Column("category", sa.String(16), nullable=False),
                    sa.Column("message", sa.Text, nullable=False), sa.Column("node_id", sa.String(36)),
                    sa.Column("actor", sa.String(64)), sa.Column("correlation_id", sa.String(36)), sa.Column("data", sa.JSON, nullable=False))
    for field in ("created_at", "category", "node_id"):
        op.create_index(f"ix_events_{field}", "events", [field])


def downgrade():
    for table in ("events", "commands", "confirmations", "scans", "links", "sessions", "members", "scene"):
        op.drop_table(table)
