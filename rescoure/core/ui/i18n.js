/**
 * FiveCore i18n — Shared NUI Translation Module
 *
 * Verwendung:
 *   i18n.setLocale(localeObj)   — Locale aus Lua laden
 *   i18n.t('key', ...args)      — Übersetzten String holen
 *   i18n.apply()                — Alle [data-i18n] Elemente im DOM übersetzen
 */

window.i18n = (() => {
    let _locale = {};

    /** Übersetzung abrufen (mit optionalem sprintf-ähnlichem Ersetzen) */
    function t(key, ...args) {
        let str = _locale[key] ?? key;
        if (args.length > 0) {
            let i = 0;
            str = str.replace(/%[sd]/g, () => args[i++] ?? '');
        }
        return str;
    }

    /** Locale-Objekt setzen */
    function setLocale(localeObj) {
        if (localeObj && typeof localeObj === 'object') {
            _locale = localeObj;
        }
    }

    /**
     * DOM übersetzen:
     *  <span data-i18n="key">Fallback</span>
     *  <input data-i18n-placeholder="key" placeholder="...">
     *  <button data-i18n="key">...</button>
     */
    function apply(root) {
        const el = root || document;
        el.querySelectorAll('[data-i18n]').forEach(node => {
            node.textContent = t(node.dataset.i18n);
        });
        el.querySelectorAll('[data-i18n-placeholder]').forEach(node => {
            node.placeholder = t(node.dataset.i18nPlaceholder);
        });
        el.querySelectorAll('[data-i18n-title]').forEach(node => {
            node.title = t(node.dataset.i18nTitle);
        });
        el.querySelectorAll('[data-i18n-value]').forEach(node => {
            node.value = t(node.dataset.i18nValue);
        });
    }

    return { t, setLocale, apply };
})();
