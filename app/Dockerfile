# ── Stage 1: Dependency builder ───────────────────────────────────────────────
FROM python:3.11-slim AS builder

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt


# ── Stage 2: Lean runtime image ───────────────────────────────────────────────
FROM python:3.11-slim

# Security: dedicated non-root user
RUN groupadd -r appuser && useradd -r -g appuser appuser

WORKDIR /app

# Copy installed packages from builder stage
COPY --from=builder /root/.local /home/appuser/.local

# Copy application source
COPY src/ .

# Gunicorn writes pid/temp files to /tmp — pre-create with correct ownership
# so the read-only root filesystem constraint is satisfied
RUN mkdir -p /tmp && chown -R appuser:appuser /app /tmp

USER appuser

ENV PATH=/home/appuser/.local/bin:$PATH
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV PORT=5000

EXPOSE 5000

# Container-level health check (Kubernetes probes are the primary mechanism)
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:5000/health')"

# --worker-tmp-dir points gunicorn's heartbeat files at the tmpfs mount
CMD ["gunicorn", \
     "--bind", "0.0.0.0:5000", \
     "--workers", "2", \
     "--timeout", "60", \
     "--worker-tmp-dir", "/tmp", \
     "app:app"]
