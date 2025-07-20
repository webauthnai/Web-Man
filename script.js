// WebAuthn.AI Website JavaScript
// Smooth animations and interactive features

document.addEventListener('DOMContentLoaded', function() {
    // Initialize all functionality
    initScrollAnimations();
    initNavbarBehavior();
    initMobileMenu();
    initStatCounters();
    initBrowserMockup();
    initParallax();
    initFormValidation();
    
    console.log('🕷️🦹🏾‍♂️ WebAuthn.AI website loaded successfully!');
});

// Scroll animations with Intersection Observer
function initScrollAnimations() {
    // Check if animations should be enabled
    const animationsSupported = 'IntersectionObserver' in window && 
                               !window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    
    if (animationsSupported) {
        document.body.classList.add('js-animations-enabled');
    }
    
    const observerOptions = {
        threshold: 0.1,
        rootMargin: '0px 0px -50px 0px'
    };

    const observer = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                entry.target.classList.add('fade-in-up');
                entry.target.style.opacity = '1';
                entry.target.style.transform = 'translateY(0)';
                observer.unobserve(entry.target);
            }
        });
    }, observerOptions);

    // Observe elements for animation
    const animatedElements = document.querySelectorAll(
        '.feature-card, .tech-category, .demo-card, .stat-card, .section-header'
    );
    
    animatedElements.forEach(el => {
        // Only observe elements if animations are supported
        if (animationsSupported) {
            observer.observe(el);
            
            // Fallback: ensure elements become visible after 3 seconds
            setTimeout(() => {
                if (!el.classList.contains('fade-in-up')) {
                    el.style.opacity = '1';
                    el.style.transform = 'translateY(0)';
                    el.style.transition = 'opacity 0.5s ease, transform 0.5s ease';
                }
            }, 3000);
        }
    });
}

// Navbar behavior on scroll
function initNavbarBehavior() {
    const navbar = document.querySelector('.navbar');
    let lastScrollY = window.scrollY;
    let isScrolling = false;

    window.addEventListener('scroll', () => {
        if (!isScrolling) {
            window.requestAnimationFrame(() => {
                const currentScrollY = window.scrollY;
                
                // Add/remove scrolled class for styling
                if (currentScrollY > 100) {
                    navbar.classList.add('scrolled');
                } else {
                    navbar.classList.remove('scrolled');
                }
                
                // Keep navbar always visible at top
                navbar.style.transform = 'translateY(0)';
                
                lastScrollY = currentScrollY;
                isScrolling = false;
            });
        }
        isScrolling = true;
    });
}

// Mobile menu functionality
function initMobileMenu() {
    // Create mobile menu button
    const navContainer = document.querySelector('.nav-container');
    const navLinks = document.querySelector('.nav-links');
    
    const mobileMenuBtn = document.createElement('button');
    mobileMenuBtn.className = 'mobile-menu-btn';
    mobileMenuBtn.innerHTML = `
        <span class="hamburger-line"></span>
        <span class="hamburger-line"></span>
        <span class="hamburger-line"></span>
    `;
    mobileMenuBtn.setAttribute('aria-label', 'Toggle mobile menu');
    
    // Add mobile menu styles
    const mobileStyles = document.createElement('style');
    mobileStyles.textContent = `
        .mobile-menu-btn {
            display: none;
            flex-direction: column;
            background: none;
            border: none;
            cursor: pointer;
            padding: 8px;
            gap: 4px;
        }
        
        .hamburger-line {
            width: 24px;
            height: 3px;
            background: var(--text-primary);
            border-radius: 2px;
            transition: var(--transition-fast);
        }
        
        .mobile-menu-btn.active .hamburger-line:nth-child(1) {
            transform: rotate(45deg) translate(6px, 6px);
        }
        
        .mobile-menu-btn.active .hamburger-line:nth-child(2) {
            opacity: 0;
        }
        
        .mobile-menu-btn.active .hamburger-line:nth-child(3) {
            transform: rotate(-45deg) translate(6px, -6px);
        }
        
        @media (max-width: 768px) {
            .mobile-menu-btn {
                display: flex;
            }
            
            .nav-links {
                position: fixed;
                top: 80px;
                left: 0;
                right: 0;
                background: rgba(255, 255, 255, 0.98);
                backdrop-filter: blur(10px);
                flex-direction: column;
                padding: 2rem;
                gap: 1.5rem;
                transform: translateY(-100%);
                opacity: 0;
                transition: var(--transition-normal);
                border-top: 1px solid var(--border-light);
                z-index: 999;
            }
            
            .nav-links.active {
                transform: translateY(0);
                opacity: 1;
            }
            
            .nav-links a {
                font-size: 1.125rem;
                text-align: center;
                padding: 0.75rem;
                border-radius: 0.5rem;
                transition: var(--transition-fast);
            }
            
            .nav-links a:hover {
                background: var(--background-alt);
            }
        }
    `;
    document.head.appendChild(mobileStyles);
    
    navContainer.appendChild(mobileMenuBtn);
    
    // Toggle mobile menu
    mobileMenuBtn.addEventListener('click', () => {
        mobileMenuBtn.classList.toggle('active');
        navLinks.classList.toggle('active');
        
        // Prevent body scroll when menu is open
        document.body.style.overflow = navLinks.classList.contains('active') ? 'hidden' : '';
    });
    
    // Close menu when clicking on links
    navLinks.addEventListener('click', (e) => {
        if (e.target.tagName === 'A') {
            mobileMenuBtn.classList.remove('active');
            navLinks.classList.remove('active');
            document.body.style.overflow = '';
        }
    });
}

// Animated stat counters
function initStatCounters() {
    const statNumbers = document.querySelectorAll('.stat-number');
    
    const countObserver = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                const target = entry.target;
                const finalValue = target.textContent.trim();
                
                // Animate numeric values
                if (!isNaN(parseInt(finalValue))) {
                    animateNumber(target, parseInt(finalValue));
                } else if (finalValue === '∞') {
                    // Special animation for infinity symbol
                    target.style.animation = 'pulse 2s infinite';
                }
                
                countObserver.unobserve(target);
            }
        });
    }, { threshold: 0.5 });
    
    statNumbers.forEach(stat => countObserver.observe(stat));
}

function animateNumber(element, finalValue) {
    let startValue = 0;
    const duration = 2000;
    const startTime = performance.now();
    
    function updateNumber(currentTime) {
        const elapsed = currentTime - startTime;
        const progress = Math.min(elapsed / duration, 1);
        
        // Easing function for smooth animation
        const easeOut = 1 - Math.pow(1 - progress, 3);
        const currentValue = Math.floor(startValue + (finalValue - startValue) * easeOut);
        
        element.textContent = currentValue === 0 && finalValue > 0 ? '1' : currentValue.toString();
        
        if (progress < 1) {
            requestAnimationFrame(updateNumber);
        } else {
            element.textContent = finalValue.toString();
        }
    }
    
    requestAnimationFrame(updateNumber);
}

// Browser mockup interactions
function initBrowserMockup() {
    const browserMockup = document.querySelector('.browser-mockup');
    const addressBar = document.querySelector('.address-bar');
    const authAnimation = document.querySelector('.auth-animation');
    
    if (!browserMockup) return;
    
    // Add hover effects
    browserMockup.addEventListener('mouseenter', () => {
        browserMockup.style.transform = 'perspective(1000px) rotateY(-2deg) rotateX(2deg) scale(1.02)';
    });
    
    browserMockup.addEventListener('mouseleave', () => {
        browserMockup.style.transform = 'perspective(1000px) rotateY(-5deg) rotateX(5deg) scale(1)';
    });
    
    // Simulate typing in address bar
    if (addressBar) {
        const urls = ['chat.webauthn.ai', 'webauthn.io', 'webauthn.me'];
        let currentUrlIndex = 0;
        
        setInterval(() => {
            const urlElement = addressBar.querySelector('.url');
            if (urlElement) {
                urlElement.style.opacity = '0';
                setTimeout(() => {
                    currentUrlIndex = (currentUrlIndex + 1) % urls.length;
                    urlElement.textContent = urls[currentUrlIndex];
                    urlElement.style.opacity = '1';
                }, 300);
            }
        }, 4000);
    }
    
    // Animate ripples in auth animation
    if (authAnimation) {
        setInterval(() => {
            const ripples = authAnimation.querySelectorAll('.ripple');
            ripples.forEach((ripple, index) => {
                setTimeout(() => {
                    ripple.style.animation = 'none';
                    ripple.offsetHeight; // Trigger reflow
                    ripple.style.animation = 'ripple 2s infinite';
                }, index * 700);
            });
        }, 6000);
    }
}

// Parallax effect for hero orbs
function initParallax() {
    const orbs = document.querySelectorAll('.gradient-orb');
    
    window.addEventListener('scroll', () => {
        const scrolled = window.pageYOffset;
        const rate = scrolled * -0.5;
        
        orbs.forEach((orb, index) => {
            const speed = 0.5 + (index * 0.2);
            orb.style.transform = `translateY(${rate * speed}px) rotate(${scrolled * 0.1}deg)`;
        });
    });
    
    // Mouse parallax effect
    document.addEventListener('mousemove', (e) => {
        const mouseX = e.clientX / window.innerWidth;
        const mouseY = e.clientY / window.innerHeight;
        
        orbs.forEach((orb, index) => {
            const speed = 10 + (index * 5);
            const x = (mouseX - 0.5) * speed;
            const y = (mouseY - 0.5) * speed;
            
            orb.style.transform += ` translate(${x}px, ${y}px)`;
        });
    });
}

// Form validation (if contact forms are added later)
function initFormValidation() {
    const forms = document.querySelectorAll('form');
    
    forms.forEach(form => {
        form.addEventListener('submit', (e) => {
            e.preventDefault();
            
            const formData = new FormData(form);
            const data = Object.fromEntries(formData);
            
            // Basic validation
            const requiredFields = form.querySelectorAll('[required]');
            let isValid = true;
            
            requiredFields.forEach(field => {
                if (!field.value.trim()) {
                    isValid = false;
                    field.classList.add('error');
                } else {
                    field.classList.remove('error');
                }
            });
            
            if (isValid) {
                // Simulate form submission
                showNotification('Thank you for your interest! We\'ll be in touch soon.', 'success');
                form.reset();
            } else {
                showNotification('Please fill in all required fields.', 'error');
            }
        });
    });
}

// Notification system
function showNotification(message, type = 'info') {
    const notification = document.createElement('div');
    notification.className = `notification notification-${type}`;
    notification.textContent = message;
    
    // Add notification styles
    const notificationStyles = document.createElement('style');
    notificationStyles.textContent = `
        .notification {
            position: fixed;
            top: 100px;
            right: 20px;
            background: white;
            color: var(--text-primary);
            padding: 1rem 1.5rem;
            border-radius: 0.5rem;
            box-shadow: var(--shadow-lg);
            border-left: 4px solid var(--primary-color);
            z-index: 10000;
            transform: translateX(400px);
            transition: var(--transition-normal);
            max-width: 300px;
        }
        
        .notification-success {
            border-left-color: var(--accent-color);
        }
        
        .notification-error {
            border-left-color: #e53e3e;
        }
        
        .notification.show {
            transform: translateX(0);
        }
    `;
    
    if (!document.querySelector('#notification-styles')) {
        notificationStyles.id = 'notification-styles';
        document.head.appendChild(notificationStyles);
    }
    
    document.body.appendChild(notification);
    
    // Show notification
    setTimeout(() => notification.classList.add('show'), 100);
    
    // Hide notification after 5 seconds
    setTimeout(() => {
        notification.classList.remove('show');
        setTimeout(() => notification.remove(), 300);
    }, 5000);
}

// Smooth scroll for anchor links
document.addEventListener('click', (e) => {
    if (e.target.matches('a[href^="#"]')) {
        e.preventDefault();
        const targetId = e.target.getAttribute('href').substring(1);
        const targetElement = document.getElementById(targetId);
        
        if (targetElement) {
            const offsetTop = targetElement.offsetTop - 80; // Account for fixed navbar
            
            window.scrollTo({
                top: offsetTop,
                behavior: 'smooth'
            });
        }
    }
});

// Add loading states to buttons
document.addEventListener('click', (e) => {
    if (e.target.matches('.btn[href^="http"]')) {
        const btn = e.target;
        const originalText = btn.innerHTML;
        
        btn.innerHTML = '<span>Loading...</span>';
        btn.style.pointerEvents = 'none';
        
        // Reset button after 2 seconds (simulating load time)
        setTimeout(() => {
            btn.innerHTML = originalText;
            btn.style.pointerEvents = 'auto';
        }, 2000);
    }
});

// Performance optimization: Throttle scroll events
function throttle(func, wait) {
    let timeout;
    return function executedFunction(...args) {
        const later = () => {
            clearTimeout(timeout);
            func(...args);
        };
        clearTimeout(timeout);
        timeout = setTimeout(later, wait);
    };
}

// Add CSS custom properties for scroll-based animations
function updateScrollProgress() {
    const scrollProgress = window.pageYOffset / (document.documentElement.scrollHeight - window.innerHeight);
    document.documentElement.style.setProperty('--scroll-progress', scrollProgress);
}

window.addEventListener('scroll', throttle(updateScrollProgress, 16)); // ~60fps

// Accessibility improvements
document.addEventListener('keydown', (e) => {
    // ESC key closes mobile menu
    if (e.key === 'Escape') {
        const mobileMenuBtn = document.querySelector('.mobile-menu-btn');
        const navLinks = document.querySelector('.nav-links');
        
        if (navLinks && navLinks.classList.contains('active')) {
            mobileMenuBtn.classList.remove('active');
            navLinks.classList.remove('active');
            document.body.style.overflow = '';
        }
    }
});

// Prefers reduced motion support
if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
    // Disable animations for users who prefer reduced motion
    const style = document.createElement('style');
    style.textContent = `
        *, *::before, *::after {
            animation-duration: 0.01ms !important;
            animation-iteration-count: 1 !important;
            transition-duration: 0.01ms !important;
            scroll-behavior: auto !important;
        }
    `;
    document.head.appendChild(style);
}

// Console easter egg
console.log(`
🕷️🦹🏾‍♂️ WebAuthn.AI - The Future of Passwordless Web

Built with:
🤖 100% AI Engineering
🔐 FIDO2/WebAuthn Compliance  
🐶🪪 DogTag Passkey System
⚡ Lightning Performance
🛡️ Unhackable Security

Ready to experience the future? Try WebMan browser!
GitHub: https://github.com/webauthnai/Web-Man
Demo: https://chat.webauthn.ai

Prompting Engineering by FIDO3.ai
`);

// Export functions for potential use
window.WebAuthnAI = {
    showNotification,
    animateNumber,
    throttle
}; 