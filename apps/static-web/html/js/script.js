// ── Nav scroll border ──────────────────────────────────────────
const nav = document.getElementById('nav');
window.addEventListener('scroll', () => {
  nav.classList.toggle('scrolled', window.scrollY > 50);
});

// ── Reveal on scroll ───────────────────────────────────────────
const observer = new IntersectionObserver((entries) => {
  entries.forEach(entry => {
    if (entry.isIntersecting) entry.target.classList.add('visible');
  });
}, { threshold: 0.1 });

document.querySelectorAll('.reveal').forEach(el => observer.observe(el));

// ── Terminal typewriter (staggered fade-in) ────────────────────
function animateTerminal(terminalId, delayStart) {
  const lines = document.querySelectorAll(`#${terminalId} .t-line, #${terminalId} .t-out`);
  lines.forEach((line, i) => {
    line.style.opacity = '0';
    line.style.transition = 'opacity 0.25s';
    setTimeout(() => { line.style.opacity = '1'; }, delayStart + i * 120);
  });
}

animateTerminal('terminal-portero', 600);
animateTerminal('terminal-iac', 800);

// ── MOTD live date ─────────────────────────────────────────────
const motdDate = document.getElementById('motd-date');
if (motdDate) {
  const now = new Date();
  motdDate.textContent = now.toLocaleString('en-GB', {
    weekday: 'short', day: '2-digit', month: 'short',
    year: 'numeric', hour: '2-digit', minute: '2-digit'
  });
}

// ── Smooth scroll for anchor links ────────────────────────────
document.querySelectorAll('a[href^="#"]').forEach(a => {
  a.addEventListener('click', e => {
    const target = document.querySelector(a.getAttribute('href'));
    if (target) {
      e.preventDefault();
      target.scrollIntoView({ behavior: 'smooth' });
    }
  });
});

// ── Blood particle on click ────────────────────────────────────
const particleStyle = document.createElement('style');
particleStyle.textContent = `
  @keyframes dotFade {
    0%   { transform: scale(1); opacity: 1; }
    100% { transform: scale(8); opacity: 0; }
  }
`;
document.head.appendChild(particleStyle);

document.addEventListener('click', (e) => {
  const dot = document.createElement('div');
  dot.style.cssText = `
    position:fixed; left:${e.clientX}px; top:${e.clientY}px;
    width:4px; height:4px; background:#c0392b; border-radius:50%;
    pointer-events:none; z-index:9999;
    animation: dotFade 0.5s ease forwards;
  `;
  document.body.appendChild(dot);
  setTimeout(() => dot.remove(), 500);
});
