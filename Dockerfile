# LiteLLM Gateway - Custom Image
# Includes litellm_config.yaml baked in

FROM docker.litellm.ai/berriai/litellm:main-v1.81.0-nightly

# Copy config file into the container
COPY litellm_config.yaml /app/litellm_config.yaml

# Expose port
EXPOSE 4000

# Start LiteLLM with config
CMD ["--config", "/app/litellm_config.yaml"]
