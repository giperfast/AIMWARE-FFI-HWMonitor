--[[
    <meta name="author" content="giperfast">
    shit code prod.
]]--
ffi.cdef[[
    typedef struct _MEMORYSTATUSEX {
        unsigned long dwLength;
        unsigned long dwMemoryLoad;
        unsigned __int64 ullTotalPhys;
        unsigned __int64 ullAvailPhys;
        unsigned __int64 ullTotalPageFile;
        unsigned __int64 ullAvailPageFile;
        unsigned __int64 ullTotalVirtual;
        unsigned __int64 ullAvailVirtual;
        unsigned __int64 ullAvailExtendedVirtual;
    } MEMORYSTATUSEX, *LPMEMORYSTATUSEX;
    
    typedef struct _FILETIME {
        unsigned long dwLowDateTime;
        unsigned long dwHighDateTime;
    } FILETIME, *PFILETIME, *LPFILETIME;

    uint32_t GetSystemTimes(PFILETIME lpIdleTime , PFILETIME lpKernelTime , PFILETIME  lpUserTime );

    uint32_t GlobalMemoryStatusEx(LPMEMORYSTATUSEX);

    typedef void* (__cdecl* tCreateInterface)(const char* name, int* returnCode);
    void* GetProcAddress(void* hModule, const char* lpProcName);
    void* GetModuleHandleA(const char* lpModuleName);

]]
function CreateInterface(module_name, interface_name)
    return ffi.cast("tCreateInterface", ffi.C.GetProcAddress(ffi.C.GetModuleHandleA(module_name), "CreateInterface"))(interface_name, ffi.new("int*"))
end

local engine = CreateInterface("engine.dll", "VEngineClient014")
local engineCast = ffi.cast(ffi.typeof('void***'), engine)
local getNetinfo = ffi.cast("void*(__thiscall*)(void*)", engineCast[0][78])
local wScreen, hScreen  = draw.GetScreenSize()
scale = wScreen/2560
font = draw.CreateFont("Bahnschrift", 17*scale, 100)

local Ref               = gui.Tab(gui.Reference('Settings'), 'HWMonitor.tab', 'HWMonitor Settings');
local Groupbox 		    = gui.Groupbox( Ref, "HWMonitor Settings", 15, 15, 300, 500 )
local Groupbox2 		= gui.Groupbox( Ref, "HWMonitor Colors", 330, 15, 295, 500 )
local multibox          = gui.Multibox( Groupbox, 'Render settings');

local cpu_enable        = gui.Checkbox( multibox, 'HWMonitor.render.cpu', 'CPU', true );
local cpu_color         = gui.ColorPicker(cpu_enable, "HWMonitor.color.cpu", "CPU color", 0, 255, 255, 255);

local ram_enable        = gui.Checkbox( multibox, 'HWMonitor.render.ram', 'RAM', true );
local ram_color         = gui.ColorPicker(ram_enable, "HWMonitor.color.ram", "RAM color", 255, 0, 255, 255);

local bytes_enable      = gui.Checkbox( multibox, 'HWMonitor.render.bytes', 'BYTES', true );
local bytes_color         = gui.ColorPicker(bytes_enable, "HWMonitor.color.bytes", "BYTES color", 255, 255, 0, 255);


local background_color  = gui.ColorPicker(Groupbox2, "HWMonitor.color.background", "Background color", 0, 0, 0, 100);
local header_color      = gui.ColorPicker(Groupbox2, "HWMonitor.color.header", "Header color", 0, 0, 0, 50);
local outline_color     = gui.ColorPicker(Groupbox2, "HWMonitor.color.outline", "Outline color", 0, 0, 0, 100);
local header_text_color = gui.ColorPicker(Groupbox2, "HWMonitor.color.header_text", "Header text color", 255, 255, 255, 255);

local wSlider 		    = gui.Slider( Groupbox, 'HWMonitor.w', 'w', 0, 0, wScreen-500*scale )
local hSlider		    = gui.Slider( Groupbox, 'HWMonitor.h', 'h', 0, 0, hScreen-15*scale)

wSlider:SetInvisible(true)
hSlider:SetInvisible(true)

local DRAG = {
    chd_move_x = wScreen-520,
    chd_move_y = hScreen/2,
    chd_offset_x = 0,
    chd_offset_y = 0,
    chd_drag = 0,
}

local CPU = {
    CPU = 0,
    InterpolatedCPU = 0,
    last_getCPU = 0,
    historyCPU = {},
    GraphCPU = 0,
    AnimstateCPU = 0,
    FadeCPU = 0,
}

local RAM = {
    RAM = 1,
    InterpolatedRAM = 0,
    last_getRAM = 0,
    historyRAM = {},
    GraphRAM = 0,
    AnimstateRAM = 0,
    FadeRAM = 0,
}

local NET = {
    BYTES = 1,
    last_NETBYTE = 0,
    historyBYTES = {},
    GraphBYTE = 0,
    AnimstateBYTE = 0,
    FadeBYTE = 0,
}

local _previousTotalTicks, _previousIdleTicks, _oldRet  = 0, 0, 0;

function CalculateCPULoad(idleTicks, totalTicks)

    totalTicksSinceLastTime = totalTicks - _previousTotalTicks;
    idleTicksSinceLastTime = idleTicks - _previousIdleTicks;

    if totalTicksSinceLastTime > 0 then
        ret = 100 - (100 * idleTicksSinceLastTime / totalTicksSinceLastTime) + 1
    end
    _previousTotalTicks = totalTicks;
    _previousIdleTicks = idleTicks;

    if ret and ret > 0 and ret < 100 then 
        _oldRet = ret
    end
    return _oldRet;

end

local function cpu()
    if cpu_enable:GetValue() == false then
        return
    else
        if (globals.RealTime() - CPU.last_getCPU > 0.2) then
            local idleTime = ffi.new('FILETIME')
            local kernelTime = ffi.new('FILETIME')
            local userTime = ffi.new('FILETIME')
            ffi.C.GetSystemTimes(idleTime, kernelTime, userTime)
            local idleTimeint64 = bit.bxor(bit.rshift(idleTime.dwHighDateTime, 32), idleTime.dwLowDateTime)
            local kernelTimeint64 = bit.bxor(bit.rshift(kernelTime.dwHighDateTime, 32), kernelTime.dwLowDateTime)
            local userTimeint64 = bit.bxor(bit.rshift(userTime.dwHighDateTime, 32), userTime.dwLowDateTime)

            CPU.CPU = CalculateCPULoad(idleTimeint64, kernelTimeint64+userTimeint64)
            CPU.last_getCPU = globals.RealTime();
        end
        if CPU.CPU > CPU.InterpolatedCPU then
            if CPU.CPU - CPU.InterpolatedCPU >= 1 then
                if CPU.CPU ~= CPU.InterpolatedCPU then
                    CPU.InterpolatedCPU = CPU.InterpolatedCPU+0.1
                end
            end
        elseif CPU.CPU < CPU.InterpolatedCPU then
            if CPU.CPU - CPU.InterpolatedCPU <= 1 then
                if CPU.CPU ~= CPU.InterpolatedCPU then
                    CPU.InterpolatedCPU = CPU.InterpolatedCPU-0.1
                end
            end
        end
        return InterpolatedCPU
    end 
end

local function ram()
    if ram_enable:GetValue() == false then
        return
    else
        if (globals.RealTime() - RAM.last_getRAM > 1) then
            MEMORYSTATUSEX = ffi.new('MEMORYSTATUSEX')
            MEMORYSTATUSEX.dwLength = ffi.sizeof(MEMORYSTATUSEX)
            ffi.C.GlobalMemoryStatusEx(MEMORYSTATUSEX)
            RAM.RAM = MEMORYSTATUSEX.dwMemoryLoad
            RAM.last_getRAM = globals.RealTime();
        end
        if RAM.RAM > RAM.InterpolatedRAM then
            if RAM.RAM - RAM.InterpolatedRAM >= 1 then
                if RAM.RAM ~= RAM.InterpolatedRAM then
                    RAM.InterpolatedRAM = RAM.InterpolatedRAM+0.1
                end
            end
        elseif RAM.RAM < RAM.InterpolatedRAM then
            if RAM.RAM ~= RAM.InterpolatedRAM then
                RAM.InterpolatedRAM = RAM.InterpolatedRAM-0.1
            end
        end
        return RAM.InterpolatedRAM
    end
end

local function netInfo()
    if (globals.RealTime() - NET.last_NETBYTE > 1) then
        local netInfo = ffi.cast("void***", getNetinfo(engineCast))
        if netInfo ~= nil then
            sent_bytes = ffi.cast(ffi.typeof("float(__thiscall*)(void*, int)"), netInfo[0][13])(netInfo, 0)
            bytesout = 'out: '..(sent_bytes/1024)..'k/s'
            NET.BYTES = sent_bytes/1024
        else
            NET.BYTES = 0
        end
        NET.last_NETBYTE = globals.RealTime();
    end
    return NET.BYTES
end

local function is_inside(a, b, x, y, w, h)
    return a >= x and a <= w and b >= y and b <= h
end

local function m_drag(x, y, w, h)
    if DRAG.chd_move_x == wScreen-520 and DRAG.chd_move_y == hScreen/2 then
        wSlider:SetValue(wScreen-520)
        hSlider:SetValue(hScreen/2)
    end
    if not gui.Reference("MENU"):IsActive() then
        return DRAG.chd_move_x, DRAG.chd_move_y
    end
    local mouse_down = input.IsButtonDown(1)
    if mouse_down then
        local mouse_x, mouse_y = input.GetMousePos()
        if not drag then
            local w, h = x + w, y + h
            if is_inside(mouse_x, mouse_y, x, y, w, h) then
                DRAG.chd_offset_x = mouse_x - x
                DRAG.chd_offset_y = mouse_y - y
                drag = true
            else
                DRAG.chd_move_y = hSlider:GetValue()
                DRAG.chd_move_x = wSlider:GetValue()
            end
        else
            DRAG.chd_move_x = mouse_x - DRAG.chd_offset_x
            DRAG.chd_move_y = mouse_y -DRAG. chd_offset_y
            wSlider:SetValue(DRAG.chd_move_x)
            hSlider:SetValue(DRAG.chd_move_y)
        end
    else
        drag = false
    end
    return DRAG.chd_move_x, DRAG.chd_move_y
end

local function graph(vel, type, article , x, y, array, last, state, fadestate, r, g, b, a)
    if type ~= 'OUT' then
        value = math.ceil(vel)
    else
        value = tonumber(string.format("%.3f", vel))
    end
    local height = 565
    local w = 490*scale
    
    x = x - (w / 2)
    if (last + 5 < globals.TickCount()) then
        local temp = {}
        temp.vel = math.min(vel*5.65*scale, height)
        table.insert(array, temp)
        last = globals.TickCount()
    end

    local over = (#array - w / 0.5)*scale
    if over > 0 then
        table.remove(array, 1)
    end
    
    for i = 1, #array, 1 do
        if state == 0 then
            fadestate = fadestate + 1
            if fadestate >= 255 then
                fadestate = 255
                state = 1
            end
        end
        draw.Color(r, g, b, fadestate)
        if i > 1 then
            X2 = x + ((i * 0.5))
            X1 = x + ((i - 1) * 0.5)
            Y2 = y - (array[i].vel / 3.4)
            Y1 = y - (array[i-1].vel / 3.4)
            draw.Line(X1, Y1, X2, Y2)

        end
    end
    if X2 then
        if value > 90 then
            draw.TextShadow( X2-draw.GetTextSize( type..' '..value..''..article ), Y2+10*scale, type..' '..value..''..article )
        else
            draw.TextShadow( X2-draw.GetTextSize( type..' '..value..''..article ), Y2-20*scale, type..' '..value..''..article )
        end
    end
end

local alphaline = 0
local alphabg = 0
local alphaheader = 0
local alphatext = 0
local animstate = 0

function setalpha(value, curr)
    if cpu_enable:GetValue() or ram_enable:GetValue() or bytes_enable:GetValue() then
        if value >= curr and value ~= 0    then
            value = value - 1
        else
            value = value + 1
        end
    else
        if value > 0 then
            value = value - 1
        end
    end
    return value
end

if scale == 0.75 then
    scale60 = 45
    scale65 = 50
elseif scale == 1.5 then
    scale60 = 100
    scale65 = 105
else
    scale60 = 60
    scale65 = 65
end

local function render()
    local offset = 0
    local x, y = m_drag(wSlider:GetValue(), hSlider:GetValue(), 500*scale, 20*scale)
    if x < 0 then x=0 elseif x > wScreen-500*scale then x=wScreen-500*scale elseif y < 0 then y=0 elseif y > hScreen-15*scale then y=hScreen-15*scale end
    draw.SetFont(font);

    local rBG, gBG, bBG, aBG = background_color:GetValue();
    local rHD, gHD, bHD, aHD = header_color:GetValue();
    local rOL, gOL, bOL, aOL = outline_color:GetValue();
    local rTEXT, gTEXT, bTEXT, aTEXT = header_text_color:GetValue();

    local rCPU, gCPU, bCPU, aCPU = cpu_color:GetValue();
    local rRAM, gRAM, bRAM, aRAM = ram_color:GetValue();
    local rBYTES, gBYTES, bBYTES, aBYTES = bytes_color:GetValue();

    alphatext = setalpha(alphatext, aTEXT)
    alphaline = setalpha(alphaline, aOL)
    alphaheader = setalpha(alphaheader, aHD)
    alphabg = setalpha(alphabg, aBG)

    draw.SetScissorRect(x, y, x+500*scale, y+200*scale);

    draw.Color( rOL, gOL, bOL, alphaline )
    draw.OutlinedRect( x, y, x+500*scale, y+200*scale )--outline 
    draw.Line( x, y + 20 *scale, x+500*scale, y + 20*scale )

    draw.Color( rBG, gBG, bBG, alphabg )
    draw.FilledRect( x, y, x+500*scale, y+200*scale )--bg

    draw.Color( rHD, gHD, bHD, alphaheader )
    draw.FilledRect( x, y + 20*scale , x+500*scale, y )--header
    if cpu_enable:GetValue() == true then
        offset = offset + 1
        draw.Color( rTEXT, gTEXT, bTEXT, alphatext )
        cpu()
        draw.TextShadow( x-scale60+offset*scale65, y+5*scale, 'CPU'..' '..math.ceil(CPU.InterpolatedCPU)..'%' )
        graph(CPU.InterpolatedCPU,'CPU', '%', x+249*scale, y+194*scale, CPU.historyCPU, CPU.GraphCPU, CPU.AnimstateCPU, CPU.FadeCPU, rCPU, gCPU, bCPU, aCPU)
    else
        CPU.historyCPU = {}
        NET.AnimstateCPU = 0
        NET.FadeCPU = 0
    end
    if ram_enable:GetValue() == true then
        offset = offset + 1
        draw.Color( rTEXT, gTEXT, bTEXT, alphatext )
        ram()
        draw.TextShadow( x-scale60+offset*scale65, y+5*scale, 'RAM'..' '..math.ceil(RAM.InterpolatedRAM)..'%' )
        graph(RAM.InterpolatedRAM,'RAM', '%', x+249*scale, y+194*scale, RAM.historyRAM, RAM.GraphRAM, RAM.AnimstateRAM, RAM.FadeRAM, rRAM, gRAM, bRAM, aRAM)
    else
        RAM.historyRAM = {}
        NET.AnimstateRAM = 0
        NET.FadeRAM = 0
    end
    if bytes_enable:GetValue() == true then
        offset = offset + 1
        draw.Color( rTEXT, gTEXT, bTEXT, alphatext )
        netInfo()
        draw.TextShadow( x-scale60+offset*scale65, y+5*scale, 'OUT'..' '..tonumber(string.format("%.3f", NET.BYTES))..'k/s' )
        graph(NET.BYTES,'OUT', 'k/s', x+249*scale, y+194*scale, NET.historyBYTES, NET.GraphBYTE, NET.AnimstateBYTE, NET.FadeBYTE, rBYTES, gBYTES, bBYTES, aBYTES) 
    else
        NET.historyBYTES = {}
        NET.AnimstateBYTE = 0
        NET.FadeBYTE = 0
    end
    draw.SetScissorRect(0, 0, draw.GetScreenSize());
end

callbacks.Register("Draw", "Render", render)
