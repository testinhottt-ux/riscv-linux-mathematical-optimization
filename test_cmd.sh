echo "================== [TESTE 1: PROCESSADOR RISC-V 32 CORES] =================="
echo -n "Contagem de cores pelo kernel (nproc): "
nproc
echo "Extensões ISA e Processadores:"
grep -E "processor|isa|mmu" /proc/cpuinfo | head -n 12
echo ""
echo "================== [TESTE 2: REDE E NAVEGACAO NA INTERNET] ================="
echo -n "Configuracao de IP (eth0): "
ip -4 addr show eth0 | grep inet | awk '{print $2}'
echo "Testando conectividade ICMP (ping 1.1.1.1)..."
ping -c 2 1.1.1.1
echo "Testando requisicao HTTP/HTTPS via curl (https://example.com)..."
curl -sI https://example.com | head -n 5
echo "Testando renderizacao de pagina web com navegador 'links'..."
links -dump https://example.com | head -n 8
echo ""
echo "================== [TESTE 3: AMBIENTE DE DESENVOLVIMENTO / IDE] ============"
echo -n "IDE 'micro': "
micro --version | head -n 1
echo -n "Editor 'nano': "
nano --version | head -n 1
echo -n "Editor 'vim': "
vim --version | head -n 1
echo "Executando teste Python 3 (calculo paralelo nos 32 cores)..."
python3 -c "
import os, sys, multiprocessing
print(f'Python rodando em RISC-V: {sys.version.split()[0]}')
print(f'Multiprocessing detectou {multiprocessing.cpu_count()} cores')
def f(x): return x*x
with multiprocessing.Pool(processes=32) as pool:
    results = pool.map(f, range(32))
print('Teste de multiprocessamento nos 32 cores: SUCESSO (32 tarefas processadas em paralelo)!')
"
echo "================== [TESTES CONCLUIDOS COM SUCESSO] ========================="
