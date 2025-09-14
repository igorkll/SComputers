if ('serviceWorker' in navigator) {
    window.addEventListener('load', () => {
        navigator.serviceWorker.register('service-worker.js', { scope: '/SComputers/' })
            .then((registration) => {
                console.log('ServiceWorker registration successful with scope: ', registration.scope);
            })
            .catch((error) => {
                console.log('ServiceWorker registration failed: ', error);
            });
    });
}

const themeToggleButton = document.getElementById('theme-toggle');
const themeStylesheet = document.querySelector('link[rel="stylesheet"]');

const themes = [
    { style: 'style.css', color: '#626262' },
    { style: 'style2.css', color: '#313131' },
    { style: 'style3.css', color: '#0e3244' }
];

const currentTheme = localStorage.getItem('theme');
let currentThemeIndex = themes.findIndex(theme => theme.style === currentTheme);
if (currentThemeIndex === -1) currentThemeIndex = 0;

themeStylesheet.setAttribute('href', themes[currentThemeIndex].style);

let themeColorMetaTag = document.querySelector('meta[name="theme-color"]');
if (!themeColorMetaTag) {
    themeColorMetaTag = document.createElement('meta');
    themeColorMetaTag.setAttribute('name', 'theme-color');
    document.head.appendChild(themeColorMetaTag);
}
themeColorMetaTag.setAttribute('content', themes[currentThemeIndex].color);

if (themeToggleButton !== null) {
    themeToggleButton.addEventListener('click', () => {
        currentThemeIndex = (currentThemeIndex + 1) % themes.length;
        
        themeStylesheet.setAttribute('href', themes[currentThemeIndex].style);
        themeColorMetaTag.setAttribute('content', themes[currentThemeIndex].color);
        
        localStorage.setItem('theme', themes[currentThemeIndex].style);
    });
}

function googleTranslateElementInit() {
    new google.translate.TranslateElement({
        pageLanguage: 'en'
    }, 'google_translate_element');
}

setTimeout(() => {
    setInterval(() => {
        //var element = document.getElementById('.skiptranslate');

        var element = document.getElementById('google_translate_element');
        if (element != null) {
            element = element.children[0];
            if (element) {
                const children = Array.from(element.children);
                children.slice(1).forEach(child => {
                    child.remove();
                });

                const childNodes = Array.from(element.childNodes);
                childNodes.forEach(child => {
                    if (child.nodeType === Node.TEXT_NODE) {
                        child.remove();
                    }
                });

                var elements = document.querySelectorAll('.skiptranslate');
                elements.forEach(element => {
                    if (element.classList.length === 1) {
                        element.remove();
                        document.body.style.top = 0;
                    }
                });
            }
        }

        var elements = document.querySelectorAll('#___gcse_0');
    
        elements.forEach(element => {
            element.style="width: 100% !important;";
        });

        var elements = document.querySelectorAll('.gsc-control-cse');
    
        elements.forEach(element => {
            element.style="background: none !important; border: none !important;";
        });
    }, 1000);
}, 100);


function loadWindow() {
    var script = document.createElement('script');
    script.async = true;
    script.src = "https://cse.google.com/cse.js?cx=319af69f537d9450e";
    document.body.insertAdjacentElement('afterbegin', script);

    var script = document.createElement('script');
    script.src = "https://translate.google.com/translate_a/element.js?cb=googleTranslateElementInit";
    document.body.insertAdjacentElement('afterbegin', script);

    var htmlString = `
    <div class="cool-block">
        <button class="image-button" onclick="window.history.back();">
            <img src="back.png" alt="back" />
        </button>
        <button class="image-button" onclick="window.location.href = 'index.html'">
            <img src="favicon.png" alt="SComputers" />
        </button>
        <button class="image-button" onclick="window.history.forward();">
            <img src="forward.png" alt="forward" />
        </button>
        <div class="gcse-search"></div>
        <div id="google_translate_element" style="margin-left: 15px !important; margin-right: 20px !important;"></div>
        <div style="margin-left: auto; display: flex;">
            <div class="image-button" style="margin-right: 5px;" onclick="window.open('https://www.youtube.com/@ololololo-l5z', '_blank');"><img src="icons/youtube.png"/></div>
            <div class="image-button" style="margin-right: 5px;" onclick="window.open('https://discord.com/users/804098593002618881', '_blank');"><img src="icons/discord.png"/></div>
            <div class="image-button" style="margin-right: 5px;" onclick="window.open('https://discord.gg/uJrsmUjaMG', '_blank');"><img src="icons/discord_server.png"/></div>
            <div class="image-button" style="margin-right: 5px;" onclick="window.open('https://steamcommunity.com/profiles/76561198977226540/', '_blank');"><img src="icons/steam.png"/></div>
            <div class="image-button" style="margin-right: 5px;" onclick="window.open('https://github.com/igorkll', '_blank');"><img src="icons/github.png"/></div>
            <div class="image-button" style="margin-right: 5px;" onclick="window.open('https://boosty.to/bananapen', '_blank');"><img src="icons/boosty.png"/></div>
            <div class="image-button" style="margin-right: 5px;" onclick="window.open('https://igorkll.github.io/logichub', '_blank');"><img src="icons/logichub.png"/></div>
        </div>
    </div>
    `;
    document.body.insertAdjacentHTML('afterbegin', htmlString);
}

window.onload = loadWindow;