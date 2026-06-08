document.addEventListener('DOMContentLoaded', () => {
    // ====================================
    // 1. Mobile Menu Toggle
    // ====================================
    const mobileMenuBtn = document.getElementById('mobileMenuBtn');
    const mobileMenu = document.getElementById('mobileMenu');
    const menuIcon = document.querySelector('.menu-icon');
    const closeIcon = document.querySelector('.close-icon');
    const navLinks = document.querySelectorAll('.mobile-link');

    mobileMenuBtn.addEventListener('click', () => {
        const isActive = mobileMenu.classList.toggle('active');
        if (isActive) {
            menuIcon.style.display = 'none';
            closeIcon.style.display = 'block';
        } else {
            menuIcon.style.display = 'block';
            closeIcon.style.display = 'none';
        }
    });

    // Close mobile menu when a link is clicked
    navLinks.forEach(link => {
        link.addEventListener('click', () => {
            mobileMenu.classList.remove('active');
            menuIcon.style.display = 'block';
            closeIcon.style.display = 'none';
        });
    });

// ====================================
// 2. Dynamic Product Loading & Filtering
// ====================================
const productsGrid = document.getElementById('productsGrid');
const tabButtons = document.querySelectorAll('.tab');

// Sample Product Data - ¡RUTAS LOCALES CONFIGURADAS!
const products = [
    { id: 1, name: "Sérum Facial de Rosa Mosqueta", category: "serum", price: 29.99, image: "./images/serum_rosa.jpeg", alt: "Sérum Facial" },
    { id: 2, name: "Crema Hidratante de Caléndula", category: "moisturizer", price: 24.50, image: "./images/crema_calendula.jpeg", alt: "Crema Hidratante" },
    { id: 3, name: "Limpiador Suave de Manzanilla", category: "cleanser", price: 18.00, image: "./images/limpiador_manzanilla.jpeg", alt: "Limpiador Facial" },
    { id: 4, name: "Mascarilla Purificante de Arcilla", category: "mask", price: 19.75, image: "./images/mascarilla_arcilla.jpeg", alt: "Mascarilla Facial" },
    { id: 5, name: "Sérum Contorno de Ojos", category: "serum", price: 35.99, image: "./images/serum_ojos.jpeg", alt: "Sérum Ojos" },
    { id: 6, name: "Hidratante Nocturna Regeneradora", category: "moisturizer", price: 32.00, image: "./images/crema_nocturna.jpeg", alt: "Crema Nocturna" },
    { id: 7, name: "Aceite Limpiador Profundo", category: "cleanser", price: 21.50, image: "./images/aceite_limpiador.jpeg", alt: "Aceite Limpiador" },
    { id: 8, name: "Mascarilla de Colágeno Marino", category: "mask", price: 25.99, image: "./images/mascarilla_colageno.jpeg", alt: "Mascarilla Colágeno" },
];

// Function to render products
const renderProducts = (category) => {
    productsGrid.innerHTML = ''; // Clear current products
    const filteredProducts = category === 'all' 
        ? products 
        : products.filter(p => p.category === category);

    filteredProducts.forEach(product => {
        const card = document.createElement('div');
        card.className = 'product-card';
        card.setAttribute('data-category', product.category);
        card.innerHTML = `
            <div class="product-image-container">
                <img src="${product.image}" alt="${product.alt}" class="product-image">
            </div>
            <div class="product-info">
                <div>
                    <p class="product-category">${product.category.charAt(0).toUpperCase() + product.category.slice(1)}</p>
                    <h3 class="product-name">${product.name}</h3>
                    <p class="product-price">€${product.price.toFixed(2)}</p>
                </div>
                <button class="add-to-cart-btn" data-product-id="${product.id}">
                    Añadir al Carrito
                </button>
            </div>
        `;
        productsGrid.appendChild(card);
    });

    // Re-attach listeners to new 'Add to Cart' buttons
    document.querySelectorAll('.add-to-cart-btn').forEach(button => {
        button.addEventListener('click', handleAddToCart);
    });
};

// Filter event listeners
tabButtons.forEach(button => {
    button.addEventListener('click', (e) => {
        // Update active tab class
        tabButtons.forEach(btn => btn.classList.remove('active'));
        e.currentTarget.classList.add('active');
        
        // Filter products
        const category = e.currentTarget.getAttribute('data-category');
        renderProducts(category);
    });
});

// Initial load: show all products
renderProducts('all');

    // ====================================
    // 3. Shopping Cart and Toast Notification
    // ====================================
    let cartCount = 0;
    const cartBadge = document.getElementById('cartBadge');
    const toast = document.getElementById('toast');
    const toastMessage = document.getElementById('toastMessage');

    const updateCartCount = (change) => {
        cartCount += change;
        cartBadge.textContent = cartCount;
    };

    const showToast = (message) => {
        toastMessage.textContent = message;
        toast.classList.add('show');
        setTimeout(() => {
            toast.classList.remove('show');
        }, 3000);
    };

    const handleAddToCart = (e) => {
        const productName = e.currentTarget.closest('.product-card').querySelector('.product-name').textContent;
        updateCartCount(1);
        showToast(`${productName} añadido al carrito.`);
    };
    
    // Initial listeners for dynamic buttons are inside renderProducts

    // ====================================
    // 4. Testimonials Carousel
    // ====================================
    const testimonialsWrapper = document.getElementById('testimonialsWrapper');
    const prevButton = document.getElementById('prevTestimonial');
    const nextButton = document.getElementById('nextTestimonial');
    const dotsContainer = document.getElementById('testimonialsDots');
    const testimonialCards = document.querySelectorAll('.testimonial-card');
    let currentIndex = 0;

    // Only enable carousel logic on mobile/small screens (where cards are stacked)
    if (window.innerWidth < 768) {
        
        const updateCarousel = () => {
            const width = testimonialCards[0].offsetWidth + 32; // Card width + gap (2rem = 32px)
            testimonialsWrapper.style.transform = `translateX(-${currentIndex * width}px)`;
            
            // Update dots
            document.querySelectorAll('.dot').forEach((dot, index) => {
                dot.classList.toggle('active', index === currentIndex);
            });
            
            // Disable/Enable buttons
            prevButton.disabled = currentIndex === 0;
            nextButton.disabled = currentIndex === testimonialCards.length - 1;
        };

        const goToNext = () => {
            if (currentIndex < testimonialCards.length - 1) {
                currentIndex++;
                updateCarousel();
            }
        };

        const goToPrev = () => {
            if (currentIndex > 0) {
                currentIndex--;
                updateCarousel();
            }
        };
        
        // Dot Navigation
        document.querySelectorAll('.dot').forEach((dot, index) => {
            dot.addEventListener('click', () => {
                currentIndex = index;
                updateCarousel();
            });
        });

        prevButton.addEventListener('click', goToPrev);
        nextButton.addEventListener('click', goToNext);

        // Initial setup
        updateCarousel(); 
        
        // Recalculate on resize (for screen-size transition)
        window.addEventListener('resize', () => {
            if (window.innerWidth < 768) {
                // Ensure we reset index and update on resize if still mobile
                currentIndex = 0; 
                updateCarousel();
            } else {
                // On desktop, reset transform and hide buttons
                testimonialsWrapper.style.transform = 'none';
            }
        });
    } else {
        // Hide navigation on desktop
        if (prevButton && nextButton && dotsContainer) {
             prevButton.style.display = 'none';
             nextButton.style.display = 'none';
             dotsContainer.style.display = 'none';
        }
    }
    
    // ====================================
    // 5. General Scroll Function (used in HTML)
    // ====================================
    window.scrollToSection = function(id) {
        const element = document.getElementById(id);
        if (element) {
            // Calculate position to account for fixed navbar height
            const navbarHeight = document.getElementById('navbar').offsetHeight;
            const top = element.offsetTop - navbarHeight - 10; // 10px buffer
            
            window.scrollTo({
                top: top,
                behavior: 'smooth'
            });
        }
    };
});