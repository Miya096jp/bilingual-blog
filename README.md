# Dual Pascal
> Note: This repository name "bilingual-blog" is a project code name.

![Tech Stack](https://skillicons.dev/icons?i=ruby,rails,postgres,docker,tailwind,cloudflare,vercel,supabase)

**A Japanese–English Bilingual Blogging Platform**

[Live Demo](https://dualpascal.com) 

Dual Pascal is a blogging platform designed for creators who want to publish content in both Japanese and English.

---

## Features

### Bilingual Publishing
* Pair Japanese and English articles as linked content
* One-click language switching
* Language-specific categories and author profiles
* Clear relationships between original and translated articles

### Writing Experience
* GFM (GitHub Flavored Markdown) support
* Syntax highlighting
* Real-time preview
* Image uploads
* SPA-like editing experience powered by Hotwire

### Customization
* Five color themes
* Three layout options
* Toggleable thumbnail display

### Authentication
* Modal-based authentication without full page reloads
* GitHub / Google social login
* Email & password authentication

### Interaction
* Comment system
* Like functionality

### Analytics (Privacy-first)
* Cookie-less, GDPR-compliant analytics with Umami
* Automatic per-user setup
* No third-party tracking scripts exposed to readers

### Architecture
* Multi-tenant design with isolated blog spaces per user
* Clean data model optimized for bilingual content management

---

## Tech Stack
### Backend
- Ruby on Rails 8.0
- PostgreSQL
- Devise
- OmniAuth
- Kramdown
- Rouge
- Active Storage

### Frontend
- Hotwire (Turbo + Stimulus)
- Tailwind CSS 4
- Slim

### Infrastructure
- Docker
- Sakura VPS
- Caddy
- Cloudflare R2

### Analytics
- Umami
- Vercel
- Supabase


## Author

**Miya096jp**

- Portfolio: (https://dualpascal.com)
- GitHub: [@Miya096jp](https://github.com/Miya096jp)
- X: [@miya096jp](https://x.com/miya096jp)

## License
This project is licensed under the MIT License.
