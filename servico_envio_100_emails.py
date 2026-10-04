#!/usr/bin/env python3
"""
Serviço Autônomo de Despacho e Auditoria de E-mails — Ecossistema RISC-V
=======================================================================
Envia o artigo científico e notificações técnicas para 100 interessados qualificados.
Critério estrito de parada: o serviço só é encerrado quando todos os 100 e-mails
forem confirmados e registrados no log de auditoria com status 'enviado_250_ok'.

Gerenciamento de Quota SMTP:
- O servidor oficial (mail.brmg.com.br:587) estabelece quota estrita de 25 e-mails/hora
  para proteção de reputação de IP (SPF/DKIM/DMARC).
- O serviço opera em modo daemon/serviço contínuo: despacha até o teto da quota horária,
  dorme durante a janela de renovação e retoma automaticamente de onde parou até atingir 100/100.
"""

import os
import sys
import time
import json
import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email.mime.base import MIMEBase
from email import encoders

SMTP_HOST = "mail.brmg.com.br"
SMTP_PORT = 587
EMAIL_SENDER = "tiago@brmg.com.br"
EMAIL_PASSWORD = os.environ.get("EMAIL_PASSWORD") or "gogorinhos"

RECIPIENTS_FILE = "/home/teste/riscv-linux/interessados_100_riscv.json"
AUDIT_LOG_FILE = "/home/teste/riscv-linux/email_dispatch_log_riscv.json"
PDF_EN = "/home/teste/riscv-linux/docs/artigo_otimizacoes_riscv_en.pdf"
PDF_PT = "/home/teste/riscv-linux/docs/artigo_otimizacoes_riscv_pt.pdf"

ZENODO_DOI = "10.5281/zenodo.23144294"
ZENODO_URL = "https://doi.org/10.5281/zenodo.23144294"
ZENODO_WEB = "https://zenodo.org/records/23144294"

MAX_PER_HOUR = 24  # Margem segura para não colidir com o limite rígido de 25


def get_smtp_connection(max_attempts=5):
    """Estabelece conexão autenticada com o servidor SMTP com retry robusto."""
    for attempt in range(1, max_attempts + 1):
        try:
            server = smtplib.SMTP(SMTP_HOST, SMTP_PORT, timeout=30)
            server.ehlo()
            server.starttls()
            server.ehlo()
            server.login(EMAIL_SENDER, EMAIL_PASSWORD)
            return server
        except Exception as e:
            print(f"[RETRY SMTP {attempt}/{max_attempts}] Falha ao conectar em {SMTP_HOST}: {e}")
            time.sleep(3 * attempt)
    return None


def load_audit_log():
    """Carrega o histórico de envios para retomada transparente."""
    if os.path.exists(AUDIT_LOG_FILE):
        try:
            with open(AUDIT_LOG_FILE, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            return {}
    return {}


def save_audit_log(log_data):
    """Grava o log de auditoria no disco atomicamente."""
    temp_file = AUDIT_LOG_FILE + ".tmp"
    with open(temp_file, "w", encoding="utf-8") as f:
        json.dump(log_data, f, indent=2, ensure_ascii=False)
    os.replace(temp_file, AUDIT_LOG_FILE)


def count_recent_sends(audit_log, window_seconds=3600):
    """Conta quantos e-mails foram enviados nos últimos 3600s."""
    now = time.time()
    count = 0
    for record in audit_log.values():
        if record.get("status") == "enviado_250_ok" and "timestamp" in record:
            try:
                t = time.mktime(time.strptime(record["timestamp"], "%Y-%m-%d %H:%M:%S"))
                if now - t < window_seconds:
                    count += 1
            except Exception:
                pass
    return count


def generate_email_content(rec):
    """Gera o corpo técnico do e-mail bilíngue com ênfase na licença dual."""
    nome = rec["nome"]
    org = rec["organizacao"]
    is_brazil = rec.get("pais") == "Brazil"

    if is_brazil:
        subject = f"Avanço no Ecossistema RISC-V: Preditor de Saltos Verilog 99%, Fim do JIT Trashing no QEMU e VirGL 3D (DOI: {ZENODO_DOI})"
        body = f"""Prezado(a) {nome} ({org}),

Espero que este e-mail o(a) encontre bem.

Compartilhamos o artigo científico e a implementação completa de otimizações matemáticas para o ecossistema RISC-V (hardware RTL, kernel Linux, emulador QEMU e aplicações):

Título: "Mathematical Optimization and Asymptotic Tuning of the RISC-V Ecosystem: From Synthesizable RTL Branch Prediction to QEMU JIT Trashing Mitigation and VirGL Acceleration"
Autor: Tiago Barbosa Dias Maciel (BRMG Research)
DOI Oficial (Zenodo CERN): {ZENODO_URL}
Acesso aos Artefatos: {ZENODO_WEB}

DESTAQUES TÉCNICOS & RESULTADOS COMPROVADOS:
1. Preditor de Desvios Bimodal em Verilog-2001:
   - Modelagem de cadeias ergódicas de Markov com contadores saturantes de 2 bits e hash XOR fold.
   - Taxa de acerto comprovada de 99%, eliminando bolhas de pipeline no processador.
2. Eliminação do JIT Trashing no QEMU TCG:
   - Resolução analítica dos gargalos do SpiderMonkey / Firefox sob emulação RV64.
   - Despacho via interpretador de bytecode estático, reduzindo as invalidações de translation blocks de >140.000/min para <120/min com complexidade amortizada O(1).
3. Aceleração Gráfica 3D VirGL via Teoria Espectral de Grafos:
   - De 0,8 FPS (llvmpipe por software) para 791,3 FPS com particionamento espectral de threads e offload direto para GPU hospedeira.
4. Tempo de Inicialização do Guest Ext4:
   - Boot do Debian GNU/Linux 13 (Trixie) com MATE Desktop reduzido para 9,29 segundos.

POLÍTICA DE LICENCIAMENTO DUAL & TERMOS DE USO:
- Uso Educacional e Acadêmico: 100% GRATUITO e sob licença aberta (CC-BY 4.0 / GPLv3) para universidades, estudantes, professores e pesquisadores.
- Uso Comercial com Royalties: Para empresas e produtos comerciais que atinjam faturamento ou lucro líquido a partir de US$ 1.000.000 (um milhão de dólares), estabelece-se o licenciamento comercial com royalty de 5% sobre a receita qualificada.

O manuscrito completo encontra-se anexado a esta mensagem e disponível permanentemente no repositório Zenodo.

Atenciosamente,

Tiago Barbosa Dias Maciel
BRMG Research / Núcleo de Arquitetura de Computadores
E-mail: tiago@brmg.com.br
OpenPGP: 19A86EA7599F4BB4
DOI: {ZENODO_URL}
"""
    else:
        subject = f"Breakthrough in RISC-V Ecosystem: 99% RTL Branch Predictor, QEMU JIT Trashing Elimination & 791 FPS VirGL (DOI: {ZENODO_DOI})"
        body = f"""Dear {nome} ({org}),

I hope this message finds you well.

We are pleased to present our latest research paper and certified technical implementations covering end-to-end mathematical and microarchitectural optimization for the RISC-V computing ecosystem:

Title: "Mathematical Optimization and Asymptotic Tuning of the RISC-V Ecosystem: From Synthesizable RTL Branch Prediction to QEMU JIT Trashing Mitigation and VirGL Acceleration"
Author: Tiago Barbosa Dias Maciel (BRMG Research)
Permanent Zenodo DOI (CERN): {ZENODO_URL}
Permanent Artifacts Repository: {ZENODO_WEB}

KEY ARCHITECTURAL ADVANCEMENTS & EMPIRICAL EVIDENCE:
1. Synthesizable Verilog-2001 Bimodal Dynamic Branch Predictor:
   - Modeled via ergodic Markov chains with 2-bit saturating up/down counters and XOR fold address hashing.
   - Attains 99% prediction accuracy on loop and conditional branch benchmarks, eliminating pipeline stalls.
2. Mathematical Elimination of QEMU TCG JIT Trashing:
   - Solved translation block (TB) invalidation storms in SpiderMonkey / Firefox ESR under RV64 dynamic binary translation.
   - Transitioning to an optimized static bytecode interpreter dispatch reduces TB flushes from >140,000/min down to <120/min with O(1) amortized complexity.
3. VirGL 3D Hardware Acceleration via Spectral Graph Partitioning:
   - Elevated rendering performance from 0.8 FPS (software llvmpipe) to 791.3 FPS via host GPU offloading.
4. Fast Guest OS Cold-Boot:
   - Cold-boot latency of Debian GNU/Linux 13 (Trixie) with MATE Desktop on 64-bit ext4 rootfs slashed to 9.29 seconds.

DUAL-LICENSING POLICY & COMMERCIAL ROYALTY TERMS:
- Academic & Educational Exemption: 100% FREE under CC-BY 4.0 / GPLv3 for universities, students, educators, and independent research.
- Commercial & Enterprise Royalty Clause: Commercial vendors, closed-source SaaS platforms, and proprietary ASIC/FPGA manufacturers generating gross revenues or net profits in excess of US$ 1,000,000 (one million US dollars) are subject to a 5% royalty agreement on qualifying income.

The complete paper is attached to this email and archived at the CERN Zenodo repository.

Warm regards,

Tiago Barbosa Dias Maciel
BRMG Research / Computer Architecture Group
Email: tiago@brmg.com.br
OpenPGP: 19A86EA7599F4BB4
DOI: {ZENODO_URL}
"""

    return subject, body, is_brazil


def run_service():
    """Loop persistente do serviço de e-mail que só encerra quando todos os 100 forem enviados."""
    print("=" * 80)
    print("SERVIÇO AUTÔNOMO DE ENVIO PARA 100 INTERESSADOS INICIADO")
    print(f"Zenodo DOI: {ZENODO_DOI}")
    print(f"Servidor SMTP: {SMTP_HOST}:{SMTP_PORT} | Remetente: {EMAIL_SENDER}")
    print("=" * 80)

    if not os.path.exists(RECIPIENTS_FILE):
        raise FileNotFoundError(f"Arquivo {RECIPIENTS_FILE} não encontrado.")

    with open(RECIPIENTS_FILE, "r", encoding="utf-8") as f:
        recipients = json.load(f)

    with open(PDF_EN, "rb") as f:
        pdf_en_bytes = f.read()
    with open(PDF_PT, "rb") as f:
        pdf_pt_bytes = f.read()

    while True:
        audit_log = load_audit_log()
        completed = {k: v for k, v in audit_log.items() if v.get("status") == "enviado_250_ok"}
        pending = [r for r in recipients if str(r["id"]) not in completed]

        total_concluido = len(completed)
        total_pendente = len(pending)

        print(f"\n[{time.strftime('%Y-%m-%d %H:%M:%S')}] STATUS DO SERVIÇO: {total_concluido}/100 enviados | {total_pendente} pendentes.")

        if total_concluido >= 100 or total_pendente == 0:
            print("\n" + "=" * 80)
            print("CONDIÇÃO DE PARADA ATINGIDA: TODOS OS 100 E-MAILS FORAM ENTREGUES COM SUCESSO!")
            print(f"Log de auditoria final verificado: {AUDIT_LOG_FILE}")
            print("=" * 80)
            break

        recent = count_recent_sends(audit_log)
        available_slots = max(0, MAX_PER_HOUR - recent)
        print(f"Envios na última hora: {recent}/{MAX_PER_HOUR} (Slots disponíveis agora: {available_slots})")

        if available_slots == 0:
            print("⏳ Quota horária segura atingida. Aguardando 15 minutos até a próxima reabertura de janela...")
            time.sleep(900)
            continue

        smtp_conn = get_smtp_connection()
        if not smtp_conn:
            print("⚠️ Conexão SMTP indisponível no momento. Aguardando 60s...")
            time.sleep(60)
            continue

        quota_hit = False
        batch_sent = 0

        for rec in pending:
            if batch_sent >= available_slots:
                print(f"Limite da janela horária atingido para este ciclo ({batch_sent} envios).")
                break

            rec_id = str(rec["id"])
            email_to = rec["email"]
            nome = rec["nome"]
            org = rec["organizacao"]

            subject, body, is_brazil = generate_email_content(rec)

            msg = MIMEMultipart()
            msg["From"] = f"Tiago Maciel <{EMAIL_SENDER}>"
            msg["To"] = email_to
            msg["Subject"] = subject
            msg.attach(MIMEText(body, "plain", "utf-8"))

            pdf_payload = pdf_pt_bytes if is_brazil else pdf_en_bytes
            filename = "artigo_otimizacoes_riscv_pt.pdf" if is_brazil else "artigo_otimizacoes_riscv_en.pdf"
            part = MIMEBase("application", "pdf")
            part.set_payload(pdf_payload)
            encoders.encode_base64(part)
            part.add_header("Content-Disposition", f"attachment; filename={filename}")
            msg.attach(part)

            try:
                smtp_conn.sendmail(EMAIL_SENDER, [email_to], msg.as_string())
                timestamp = time.strftime("%Y-%m-%d %H:%M:%S")
                record = {
                    "id": rec["id"],
                    "nome": nome,
                    "email": email_to,
                    "organizacao": org,
                    "status": "enviado_250_ok",
                    "timestamp": timestamp,
                    "doi": ZENODO_DOI
                }
                audit_log[rec_id] = record
                save_audit_log(audit_log)
                batch_sent += 1
                total_concluido = len([k for k, v in audit_log.items() if v.get("status") == "enviado_250_ok"])
                print(f"[{total_concluido}/100] [OK] Enviado para {nome} <{email_to}> ({org}) às {timestamp}")
                time.sleep(1.5)
            except smtplib.SMTPResponseException as ex:
                err_code = ex.smtp_code
                err_msg = str(ex.smtp_error)
                print(f"⚠️ Erro SMTP ao enviar para {email_to}: ({err_code}) {err_msg}")
                if err_code == 554 or "quota" in err_msg.lower() or "limite" in err_msg.lower():
                    print("🛑 Quota horária do servidor ativada. Encerrando lote imediatamente.")
                    quota_hit = True
                    break
                time.sleep(2)
            except Exception as ex:
                print(f"⚠️ Falha inesperada ao enviar para {email_to}: {ex}")
                time.sleep(2)

        try:
            smtp_conn.quit()
        except Exception:
            pass

        if quota_hit:
            print("⏳ Pausando por 20 minutos para renovação de quota no servidor SMTP...")
            time.sleep(1200)
        else:
            time.sleep(5)


if __name__ == "__main__":
    run_service()
