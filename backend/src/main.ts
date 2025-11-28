import { createApp, type DefineComponent, h } from 'vue'
import { createInertiaApp } from '@inertiajs/vue3'
import ui from '@nuxt/ui/vue-plugin'
import './style.css'
import MainLayout from './layouts/MainLayout.vue'

createInertiaApp({
    resolve: name => {
        const pages = import.meta.glob<DefineComponent>('./pages/**/*.vue', { eager: true })
        let page = pages[`./pages/${name}.vue`]
        page!.default.layout = page!.default.layout || MainLayout
        return page as any
    },
    setup({ el, App, props, plugin }) {
        createApp({ render: () => h(App, props) })
            .use(plugin)
            .use(ui)
            .mount(el)
    },
})