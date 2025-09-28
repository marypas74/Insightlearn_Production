/**
 * InsightLearn.Cloud - Theme Manager
 * Superior theme switching and design system utilities
 */

class InsightLearnThemeManager {
    constructor() {
        this.currentTheme = this.getStoredTheme() || this.getSystemTheme();
        this.init();
    }

    init() {
        this.applyTheme(this.currentTheme);
        this.setupThemeToggle();
        this.setupSystemThemeListener();
        this.setupAnimationUtils();
    }

    getSystemTheme() {
        return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
    }

    getStoredTheme() {
        return localStorage.getItem('il-theme');
    }

    storeTheme(theme) {
        localStorage.setItem('il-theme', theme);
    }

    applyTheme(theme) {
        document.documentElement.setAttribute('data-theme', theme);
        this.currentTheme = theme;
        this.storeTheme(theme);

        // Trigger custom event for components
        window.dispatchEvent(new CustomEvent('il-theme-changed', {
            detail: { theme }
        }));
    }

    toggleTheme() {
        const newTheme = this.currentTheme === 'light' ? 'dark' : 'light';
        this.applyTheme(newTheme);

        // Add smooth transition effect
        document.documentElement.style.transition = 'background-color 0.3s ease, color 0.3s ease';
        setTimeout(() => {
            document.documentElement.style.transition = '';
        }, 300);
    }

    setupThemeToggle() {
        // Find theme toggle buttons
        const themeToggles = document.querySelectorAll('[data-theme-toggle]');
        themeToggles.forEach(toggle => {
            toggle.addEventListener('click', () => this.toggleTheme());
        });
    }

    setupSystemThemeListener() {
        window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', (e) => {
            if (!this.getStoredTheme()) {
                this.applyTheme(e.matches ? 'dark' : 'light');
            }
        });
    }

    setupAnimationUtils() {
        // Setup intersection observer for scroll animations
        const observerOptions = {
            threshold: 0.1,
            rootMargin: '0px 0px -50px 0px'
        };

        const observer = new IntersectionObserver((entries) => {
            entries.forEach(entry => {
                if (entry.isIntersecting) {
                    entry.target.classList.add('il-animate-slide-up');
                }
            });
        }, observerOptions);

        // Observe elements with animation class
        document.querySelectorAll('.il-animate-on-scroll').forEach(el => {
            observer.observe(el);
        });
    }

    // Utility methods for components
    addGlassEffect(element) {
        element.classList.add('il-glass');
    }

    addNeuroEffect(element) {
        element.classList.add('il-neuro');
    }

    addHoverEffect(element, effect = 'scale') {
        element.addEventListener('mouseenter', () => {
            switch(effect) {
                case 'scale':
                    element.style.transform = 'scale(1.05)';
                    break;
                case 'lift':
                    element.style.transform = 'translateY(-4px)';
                    break;
                case 'glow':
                    element.style.boxShadow = '0 0 20px rgba(14, 165, 233, 0.3)';
                    break;
            }
        });

        element.addEventListener('mouseleave', () => {
            element.style.transform = '';
            element.style.boxShadow = '';
        });
    }

    // Performance utilities
    debounce(func, wait) {
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

    throttle(func, limit) {
        let inThrottle;
        return function() {
            const args = arguments;
            const context = this;
            if (!inThrottle) {
                func.apply(context, args);
                inThrottle = true;
                setTimeout(() => inThrottle = false, limit);
            }
        };
    }
}

// Initialize theme manager when DOM is ready
document.addEventListener('DOMContentLoaded', () => {
    window.ilTheme = new InsightLearnThemeManager();
});

// Export for module usage
if (typeof module !== 'undefined' && module.exports) {
    module.exports = InsightLearnThemeManager;
}