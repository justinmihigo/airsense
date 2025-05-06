import AppLogoIcon from './app-logo-icon';

export default function AppLogo() {
    return (
        <div className="flex items-center">
            <div className="bg-[#E6F7EC] text-[#22C55E] flex aspect-square size-8 items-center justify-center rounded-md">
                <AppLogoIcon className="size-5 fill-current text-[#22C55E]" />
            </div>
            <span className="ml-2 text-2xl font-bold text-[#22C55E] tracking-tight">AirSense<span className="text-[#4F46E5]">.</span></span>
        </div>
    );
}
