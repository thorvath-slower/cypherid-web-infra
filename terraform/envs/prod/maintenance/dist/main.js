/* SeqToID — Main JavaScript */

/* ---- Mobile Nav ---- */
const navToggle = document.getElementById('navToggle');
const navLinks  = document.querySelector('.nav-links');

if (navToggle && navLinks) {
  navToggle.addEventListener('click', () => {
    navLinks.classList.toggle('open');
    navToggle.setAttribute('aria-expanded', navLinks.classList.contains('open'));
  });
  // Close on link click
  navLinks.querySelectorAll('a').forEach(link => {
    link.addEventListener('click', () => navLinks.classList.remove('open'));
  });
}

/* ---- FAQ Accordion ---- */
document.querySelectorAll('.faq-question').forEach(btn => {
  btn.addEventListener('click', () => {
    const item = btn.closest('.faq-item');
    const isOpen = item.classList.contains('open');
    // Close all
    document.querySelectorAll('.faq-item').forEach(i => i.classList.remove('open'));
    document.querySelectorAll('.faq-question').forEach(b => b.setAttribute('aria-expanded', 'false'));
    // Toggle current
    if (!isOpen) {
      item.classList.add('open');
      btn.setAttribute('aria-expanded', 'true');
    }
  });
});

/* ---- Waitlist Form ---- */
const form        = document.getElementById('waitlistForm');
const formSuccess = document.getElementById('formSuccess');
const successEmail = document.getElementById('successEmail');

if (form) {
  form.addEventListener('submit', (e) => {
    e.preventDefault();
    let valid = true;

    // Validate name
    const nameField = document.getElementById('wl-name');
    const nameGroup = nameField.closest('.form-group');
    if (!nameField.value.trim()) {
      nameGroup.classList.add('has-error');
      nameField.classList.add('error');
      if (!nameGroup.querySelector('.field-error')) {
        const err = document.createElement('span');
        err.className = 'field-error';
        err.textContent = 'Please enter your name.';
        nameGroup.appendChild(err);
      }
      valid = false;
    } else {
      nameGroup.classList.remove('has-error');
      nameField.classList.remove('error');
    }

    // Validate email
    const emailField = document.getElementById('wl-email');
    const emailGroup = emailField.closest('.form-group');
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailField.value.trim() || !emailRegex.test(emailField.value.trim())) {
      emailGroup.classList.add('has-error');
      emailField.classList.add('error');
      if (!emailGroup.querySelector('.field-error')) {
        const err = document.createElement('span');
        err.className = 'field-error';
        err.textContent = 'Please enter a valid email address.';
        emailGroup.appendChild(err);
      }
      valid = false;
    } else {
      emailGroup.classList.remove('has-error');
      emailField.classList.remove('error');
    }

    if (!valid) return;

    // Collect form data
    const data = {
      name:        nameField.value.trim(),
      email:       emailField.value.trim(),
      institution: document.getElementById('wl-institution').value.trim(),
      role:        document.getElementById('wl-role').value,
    };

    // Build mailto link as fallback submission
    const subject = encodeURIComponent('SeqToID Waitlist Request');
    const body = encodeURIComponent(
      `Name: ${data.name}\nEmail: ${data.email}\nInstitution: ${data.institution}\nResearch Focus: ${data.role}\n\nI would like to join the SeqToID waitlist.`
    );

    // Open mailto as a fallback (silent — won't interrupt UX)
    const mailtoLink = `mailto:seqtoid@ucsf.edu?subject=${subject}&body=${body}`;

    // Show success state
    if (successEmail) successEmail.textContent = data.email;
    form.style.display = 'none';
    formSuccess.style.display = 'block';

    // Attempt to open mailto silently
    try {
      window.location.href = mailtoLink;
    } catch (err) {
      // Silently fail — success state is already shown
    }
  });

  // Remove error state on input
  form.querySelectorAll('input, select').forEach(field => {
    field.addEventListener('input', () => {
      field.classList.remove('error');
      field.closest('.form-group').classList.remove('has-error');
    });
  });
}

/* ---- Smooth scroll offset for sticky nav ---- */
document.querySelectorAll('a[href^="#"]').forEach(anchor => {
  anchor.addEventListener('click', function(e) {
    const target = document.querySelector(this.getAttribute('href'));
    if (target) {
      e.preventDefault();
      const offset = 80;
      const top = target.getBoundingClientRect().top + window.pageYOffset - offset;
      window.scrollTo({ top, behavior: 'smooth' });
    }
  });
});
