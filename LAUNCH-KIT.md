# Spit — Kit de Lançamento (sequência completa)

> Ordem: GIF → Show HN → (D+1) r/macapps → (D+2) r/opensource → (D+4) Product Hunt.
> Cada post é nativo, nunca copy-paste entre plataformas. Estar disponível para
> responder nas primeiras horas de cada um — pesa mais do que o texto.

---

## 0. GIF de demo (ANTES de tudo — 15 min)

O buraco de conversão medido: 26 visitantes vindos do X, 0 downloads. Quem chega
ao README não vê o produto a funcionar.

1. Instala o [Kap](https://getkap.co) (grátis): `brew install --cask kap`
2. Abre o Notes (fundo limpo), tamanho de janela ~800×500
3. Grava: prime ⌥ direito (ou Globe na produção) → dita uma frase natural em inglês
   ("This entire sentence was dictated with Spit — no cloud, everything on device.")
   → o texto aparece → para a gravação. **Máximo 10-12 segundos.**
4. Exporta como GIF, 800px de largura, ~10 fps → grava como `docs/demo.gif`
5. Diz-me — eu meto no README e faço push.

## 1. Show HN (o dia âncora)

Texto pronto em [SHOW-HN-DRAFT.md](SHOW-HN-DRAFT.md). Resumo operacional:
- **Quando:** 3ª ou 4ª feira, 13h-15h de Lisboa (8h-10h ET)
- **Onde:** news.ycombinator.com/submit → title + URL `https://github.com/Draxo-io/spit`
- **Logo a seguir:** cola o primeiro comentário (está no draft)
- **Depois:** fica 4-6h a responder. Rápido e tecnicamente honesto — é isso que segura o post na front page.

## 2. r/macapps (D+1) — o subreddit mais quente para isto

**Title:**
```
I built a free, open-source dictation app for macOS — 100% on-device, no subscription, no account
```

**Body:**
```
Hey everyone,

I got tired of dictation apps that either charge a monthly subscription or send
my voice to a server somewhere, so I built Spit: a menu bar app that runs
Whisper entirely on your Mac (via WhisperKit / Apple Neural Engine).

- Tap the Globe key, talk, text appears in whatever app you're using
- Live word preview while you speak
- 30+ languages, auto-detected; optional on-device translation
- Read-aloud (TTS) for selected text with the same hotkey
- Free forever, MIT licensed — the whole thing is on GitHub

Requires Apple Silicon (M1+) and macOS 14+.

GitHub: https://github.com/Draxo-io/spit
Site: https://getspit.app

It's a solo project — happy to answer anything, and bug reports are very welcome.
```

Regras do r/macapps: sem link encurtado, responder a tudo, não repostar noutros
subs no mesmo dia.

## 3. r/opensource (D+2)

**Title:**
```
Spit — on-device voice dictation for macOS (MIT). My first open-source product release
```

**Body:** ângulo diferente — a decisão de abrir o código e o modelo open-core:
```
I recently open-sourced Spit, a macOS dictation app that runs Whisper fully
on-device. It started as a paid app with a cloud backend; I ended up removing
the accounts, the subscription and the server entirely and shipping it MIT.

The reasoning: for a tool that listens to your microphone, "read the code" is
the only privacy claim that actually means something.

Stack: Swift/SwiftUI, WhisperKit for inference, zero third-party deps beyond
that, Sparkle for updates. There are a few "good first issue"s open if anyone
wants to poke at it.

https://github.com/Draxo-io/spit
```

## 4. Product Hunt (D+4, uma 3ª-feira)

- **Tagline:** `Free, on-device voice dictation for your Mac`
- **Description:** `Spit turns speech into text in any macOS app. Whisper runs
  entirely on your Mac — no cloud, no account, no subscription. Open source (MIT),
  built by a solo developer.`
- **Assets:** o GIF do README + 3 screenshots (menu bar, HUD a gravar, settings)
- **First comment (maker):** versão curta da história do SHOW-HN-DRAFT, com o
  detalhe técnico do Jetsam como "what I learned"
- Responder a todos os comentários no dia.

## 5. No dia em que passares 50-75 stars (provável no dia do HN)

Aviso-me / eu detecto — e submeto no próprio dia:
- **Homebrew Cask** (formula pronta e testada: `spit.rb`)
- **awesome-whisper** (PR pronto, exigem 100 stars)
- **awesome-voice-typing** (exigem ~50 stars)
- **alternativeTo** — precisa de conta tua: cria em alternativeto.net e lista o
  Spit como alternativa a superwhisper, Wispr Flow, MacWhisper e Dragon.

## Métricas

`./scripts/metrics.sh` a qualquer momento. No dia do lançamento, corre de manhã
e à noite — guarda os números para o post de build-in-public da semana seguinte.
