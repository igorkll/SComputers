const CACHE_NAME = 'SComputers-app-v26';

const urlsToCache = [
    'addons/brainf_ck_language.jpg',
    'addons/capture_mod.jpg',
    'addons/Controllers.jpg',
    'addons/decorative_gizmos.jpg',
    'addons/minimap_component.jpg',
    'addons/more_displays.jpg',
    'addons/online_boombox.jpg',
    'addons/power_toys.jpg',
    'addons/stretchable_display.jpg',
    'addons/world_disks.jpg',
    'addons/mt_fast_logic.jpg',
    'addons/nes.jpg',
    'icons/discord.png',
    'icons/boosty.png',
    'icons/discord_raw.png',
    'icons/discord_server.pdn',
    'icons/discord_server.png',
    'icons/discord_server_raw.png',
    'icons/github.png',
    'icons/logichub.png',
    'icons/steam.png',
    'scmframework/build_scmframework.lua',
    'scmframework/scmframework.lua',
    'canvasAPI/canvasAPI.zip',
    'service-worker.js',
    'style.css',
    'style2.css',
    'style3.css',
    'styles.html',
    'syntax.html',
    'synthesizer.html',
    'terminal.html',
    'timer.html',
    'utf8.html',
    'utils.html',
    'vdisplay.html',
    'wasd.html',
    'xEngine.html',
    'addons.html',
    'antenna.html',
    'api.html',
    'back.png',
    'base64.html',
    'camera.html',
    'cameraTunnel.html',
    'chaff.html',
    'colors.html',
    'components.html',
    'computer_data.html',
    'contact_me.html',
    'controllers.html',
    'disk.html',
    'display.html',
    'canvasAPI.html',
    'enlua.html',
    'env.html',
    'favicon.ico',
    'favicon.png',
    'fonts.html',
    'forward.png',
    'gps.html',
    'graphic.html',
    'gui.html',
    'highlight.css',
    'highlight.js',
    'holoprojector.html',
    'image.html',
    'index.html',
    'inertialEngine.html',
    'json.html',
    'keyboard.html',
    'lag_policy.html',
    'led.html',
    'libraries.html',
    'main.js',
    'making_addons.html',
    'manifest.json',
    'midi.html',
    'minimap_component.html',
    'motor.html',
    'nbs.html',
    'objs.html',
    'onlineBoombox.html',
    'paint.html',
    'pistonController.html',
    'port.html',
    'preview.png',
    'radar.html',
    'radarDetector.html',
    'ramfs.html',
    'rom.html',
    'safeSmEnv.html',
    'process.html',
    'vfs.html',
    'scriptableOS.html',
    'cameraControl.html',
    'scriptableOS_indev.html',
    'scmframework.html',
    'indev.html'
];

self.addEventListener('install', (event) => {
    event.waitUntil(
        caches.open(CACHE_NAME)
            .then((cache) => {
                return cache.addAll(urlsToCache);
            })
    );
});

self.addEventListener('activate', (event) => {
    event.waitUntil(
        caches.keys().then((cacheNames) => {
            return Promise.all(
                cacheNames.map((cacheName) => {
                    if (cacheName !== CACHE_NAME) {
                        return caches.delete(cacheName);
                    }
                })
            );
        })
    );
});

self.addEventListener('fetch', (event) => {
    event.respondWith(
        caches.match(event.request)
            .then((response) => {
                if (response) {
                    return response;
                }
                return fetch(event.request);
            })
    );
});
