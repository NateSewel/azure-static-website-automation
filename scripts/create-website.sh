# Create the website directory with a beautiful site
mkdir -p website/css website/js website/assets/images

# Create main HTML file
cat > website/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>My Azure Website</title>
    <link rel="stylesheet" href="css/style.css">
</head>
<body>
    <nav class="navbar">
        <div class="nav-container">
            <div class="logo">☁️ My Azure Site</div>
            <ul class="nav-menu">
                <li><a href="#home">Home</a></li>
                <li><a href="#about">About</a></li>
                <li><a href="#contact">Contact</a></li>
            </ul>
        </div>
    </nav>

    <section id="home" class="hero">
        <div class="hero-content">
            <div class="icon">🚀</div>
            <h1>Welcome to My Website!</h1>
            <p>Successfully deployed on Microsoft Azure</p>
            <a href="#about" class="cta-button">Learn More</a>
        </div>
    </section>

    <section id="about" class="content-section">
        <div class="container">
            <h2>🎯 About This Project</h2>
            <div class="features">
                <div class="feature-card">
                    <div class="feature-icon">☁️</div>
                    <h3>Azure Cloud</h3>
                    <p>Hosted on Microsoft Azure infrastructure</p>
                </div>
                <div class="feature-card">
                    <div class="feature-icon">🌐</div>
                    <h3>NGINX Server</h3>
                    <p>High-performance web server</p>
                </div>
                <div class="feature-card">
                    <div class="feature-icon">🔒</div>
                    <h3>Secure</h3>
                    <p>Protected by Network Security Groups</p>
                </div>
                <div class="feature-card">
                    <div class="feature-icon">⚡</div>
                    <h3>Fast & Optimized</h3>
                    <p>Gzip compression and caching enabled</p>
                </div>
            </div>
        </div>
    </section>

    <section id="contact" class="content-section alt-bg">
        <div class="container">
            <h2>📬 Contact Information</h2>
            <p>This website was deployed using Azure CLI and Infrastructure as Code principles.</p>
            <div class="tech-stack">
                <span class="tech-badge">Azure</span>
                <span class="tech-badge">NGINX</span>
                <span class="tech-badge">Ubuntu 22.04</span>
                <span class="tech-badge">Azure CLI</span>
            </div>
        </div>
    </section>

    <footer>
        <p>&copy; 2025 My Azure Website | Deployed with ❤️ using Azure Infrastructure as Code</p>
    </footer>

    <script src="js/script.js"></script>
</body>
</html>
EOF

# Create CSS file
cat > website/css/style.css << 'EOF'
* {
    margin: 0;
    padding: 0;
    box-sizing: border-box;
}

body {
    font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
    line-height: 1.6;
    color: #333;
}

/* Navigation */
.navbar {
    background: rgba(255, 255, 255, 0.95);
    backdrop-filter: blur(10px);
    box-shadow: 0 2px 10px rgba(0, 0, 0, 0.1);
    position: fixed;
    top: 0;
    width: 100%;
    z-index: 1000;
}

.nav-container {
    max-width: 1200px;
    margin: 0 auto;
    padding: 1rem 2rem;
    display: flex;
    justify-content: space-between;
    align-items: center;
}

.logo {
    font-size: 1.5rem;
    font-weight: bold;
    color: #667eea;
}

.nav-menu {
    display: flex;
    list-style: none;
    gap: 2rem;
}

.nav-menu a {
    text-decoration: none;
    color: #333;
    font-weight: 500;
    transition: color 0.3s;
}

.nav-menu a:hover {
    color: #667eea;
}

/* Hero Section */
.hero {
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    min-height: 100vh;
    display: flex;
    align-items: center;
    justify-content: center;
    text-align: center;
    color: white;
    padding: 2rem;
}

.hero-content {
    animation: fadeInUp 1s ease;
}

.icon {
    font-size: 5em;
    margin-bottom: 20px;
    animation: bounce 2s infinite;
}

@keyframes bounce {
    0%, 100% { transform: translateY(0); }
    50% { transform: translateY(-20px); }
}

.hero h1 {
    font-size: 3.5rem;
    margin-bottom: 1rem;
}

.hero p {
    font-size: 1.3rem;
    margin-bottom: 2rem;
}

.cta-button {
    display: inline-block;
    padding: 1rem 2.5rem;
    background: white;
    color: #667eea;
    text-decoration: none;
    border-radius: 50px;
    font-weight: bold;
    transition: transform 0.3s, box-shadow 0.3s;
}

.cta-button:hover {
    transform: translateY(-5px);
    box-shadow: 0 10px 30px rgba(0, 0, 0, 0.3);
}

/* Content Sections */
.content-section {
    padding: 5rem 2rem;
}

.alt-bg {
    background: #f8f9fa;
}

.container {
    max-width: 1200px;
    margin: 0 auto;
}

h2 {
    text-align: center;
    font-size: 2.5rem;
    color: #667eea;
    margin-bottom: 3rem;
}

/* Features Grid */
.features {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
    gap: 2rem;
}

.feature-card {
    background: white;
    padding: 2rem;
    border-radius: 15px;
    box-shadow: 0 5px 20px rgba(0, 0, 0, 0.1);
    text-align: center;
    transition: transform 0.3s, box-shadow 0.3s;
}

.feature-card:hover {
    transform: translateY(-10px);
    box-shadow: 0 15px 40px rgba(0, 0, 0, 0.2);
}

.feature-icon {
    font-size: 3rem;
    margin-bottom: 1rem;
}

.feature-card h3 {
    color: #667eea;
    margin-bottom: 1rem;
}

/* Tech Stack */
.tech-stack {
    display: flex;
    justify-content: center;
    gap: 1rem;
    flex-wrap: wrap;
    margin-top: 2rem;
}

.tech-badge {
    background: #667eea;
    color: white;
    padding: 0.5rem 1.5rem;
    border-radius: 25px;
    font-weight: bold;
}

/* Footer */
footer {
    background: #1a1a1a;
    color: white;
    text-align: center;
    padding: 2rem;
}

/* Animations */
@keyframes fadeInUp {
    from {
        opacity: 0;
        transform: translateY(30px);
    }
    to {
        opacity: 1;
        transform: translateY(0);
    }
}

/* Responsive */
@media (max-width: 768px) {
    .hero h1 {
        font-size: 2rem;
    }
    
    .nav-menu {
        flex-direction: column;
        gap: 1rem;
    }
    
    .features {
        grid-template-columns: 1fr;
    }
}
EOF

# Create JavaScript file
cat > website/js/script.js << 'EOF'
// Smooth scrolling for navigation
document.querySelectorAll('a[href^="#"]').forEach(anchor => {
    anchor.addEventListener('click', function (e) {
        e.preventDefault();
        const target = document.querySelector(this.getAttribute('href'));
        if (target) {
            target.scrollIntoView({
                behavior: 'smooth',
                block: 'start'
            });
        }
    });
});

// Console message
console.log('🚀 Azure Static Website loaded successfully!');
console.log('Server: NGINX on Ubuntu 22.04');
console.log('Deployed via: Azure CLI');

// Animate cards on scroll
const observer = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
        if (entry.isIntersecting) {
            entry.target.style.opacity = '1';
            entry.target.style.transform = 'translateY(0)';
        }
    });
}, { threshold: 0.1 });

document.querySelectorAll('.feature-card').forEach(card => {
    card.style.opacity = '0';
    card.style.transform = 'translateY(20px)';
    card.style.transition = 'opacity 0.6s ease, transform 0.6s ease';
    observer.observe(card);
});
EOF

echo "✅ Website files created!"