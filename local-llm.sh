export MODEL_NAME="deepseek-r1:14b"

curl -fsSL https://ollama.com/install.sh | sh
ollama --version
ollama pull ${MODEL_NAME}
ollama run ${MODEL_NAME}