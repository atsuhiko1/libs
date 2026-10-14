-- Nocturne 1.7 | Native Roblox UI | Client-side ModuleScript
-- No HTTP dependencies, hooks, game-specific behavior or external assets.
local Library = {Version = "1.7.2"}
local Players = game:GetService("Players")
local Input = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Http = game:GetService("HttpService")
local runtimeEnv=type(getgenv)=="function"and getgenv()or _G
runtimeEnv.NocturneWindowRegistry=runtimeEnv.NocturneWindowRegistry or {}
local windowRegistry=runtimeEnv.NocturneWindowRegistry

local Palette = {
    Background = Color3.fromRGB(29, 29, 34), Panel = Color3.fromRGB(24, 24, 29),
    Raised = Color3.fromRGB(48, 48, 57), Hover = Color3.fromRGB(59, 57, 66),
    Border = Color3.fromRGB(58, 57, 67), Text = Color3.fromRGB(235, 234, 238),
    Muted = Color3.fromRGB(139, 144, 162), Accent = Color3.fromRGB(222, 129, 163),
    AccentText = Color3.fromRGB(25, 20, 29), Danger = Color3.fromRGB(239, 115, 133),
    OuterEdge = Color3.fromRGB(9,9,12), Highlight = Color3.fromRGB(77,75,85),
}
local Window, Page, Section, Control = {}, {}, {}, {}
Window.__index, Page.__index, Section.__index, Control.__index = Window, Page, Section, Control
local function finite(n) return type(n) == "number" and n == n and math.abs(n) < math.huge end
local function copy(v)
    if type(v) ~= "table" then return v end
    local out = {} for k, x in pairs(v) do out[k] = copy(x) end return out
end
local function equal(a, b)
    if typeof(a) ~= typeof(b) then return false end
    if type(a) ~= "table" then return a == b end
    for k, v in pairs(a) do if not equal(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end
local function hit(gui, position)
    local p, s = gui.AbsolutePosition, gui.AbsoluteSize
    return position.X >= p.X and position.X <= p.X+s.X and position.Y >= p.Y and position.Y <= p.Y+s.Y
end
-- AbsolutePosition and touch Position use the GUI inset coordinate space.
-- GetMouseLocation uses screen coordinates, including the Roblox top bar.
local function pointer() return Input:GetMouseLocation()-GuiService:GetGuiInset() end
local function press(input)
    return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end
local function inputKey(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then return "MB1" end
    if input.UserInputType == Enum.UserInputType.MouseButton2 then return "MB2" end
    return input.KeyCode ~= Enum.KeyCode.Unknown and input.KeyCode.Name or nil
end
local function validKey(key)
    if key == "None" or key == "MB1" or key == "MB2" then return true end
    return type(key) == "string" and pcall(function() assert(Enum.KeyCode[key]) end)
end

function Window:_Connect(signal, fn, bucket)
    local connection = signal:Connect(function(...)
        if not self.Destroyed then fn(...) end
    end)
    table.insert(bucket or self._connections, connection)
    return connection
end
function Window:_Paint(object, property, key)
    self._themeNodes[object] = self._themeNodes[object] or {}
    self._themeNodes[object][property] = key
    object[property] = self.Theme[key]
end
function Window:_Node(class, parent, properties)
    local object = Instance.new(class)
    for property, value in pairs(properties or {}) do
        if type(value) == "string" and value:sub(1, 1) == "@" and self.Theme[value:sub(2)] then
            self:_Paint(object, property, value:sub(2))
        else object[property] = value end
    end
    object.Parent = parent
    return object
end
function Window:_Frame(parent, properties)
    local props = {BorderSizePixel=0, BackgroundColor3="@Panel"}
    for k, v in pairs(properties or {}) do props[k] = v end
    return self:_Node("Frame", parent, props)
end
function Window:_Text(parent, text, properties, class)
    local props = {Text=text, Font=self.Font, TextSize=12, TextColor3="@Text",
        TextStrokeColor3=Color3.new(),TextStrokeTransparency=.7,
        BackgroundTransparency=1, BorderSizePixel=0, TextXAlignment=Enum.TextXAlignment.Left,
        TextTruncate=Enum.TextTruncate.AtEnd}
    if class == "TextButton" then props.AutoButtonColor = false end
    for k, v in pairs(properties or {}) do props[k] = v end
    return self:_Node(class or "TextLabel", parent, props)
end
function Window:_Border(parent, color)
    return self:_Node("UIStroke", parent, {Color="@"..(color or "Border"), Thickness=1, ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
end
function Window:_Shade(object,soft)
    if not self.Shading then return end
    return self:_Node("UIGradient",object,{Name="Shading",Rotation=90,Color=ColorSequence.new({
        ColorSequenceKeypoint.new(0,Color3.new(1,1,1)),
        ColorSequenceKeypoint.new(.5,Color3.fromRGB(soft and 238 or 211,soft and 238 or 211,soft and 238 or 211)),
        ColorSequenceKeypoint.new(1,Color3.fromRGB(soft and 196 or 123,soft and 196 or 123,soft and 196 or 123)),
    })})
end
function Window:_Bevel(object,accent)
    self:_Shade(object)
    self:_Border(object,"OuterEdge")
    self:_Frame(object,{Name="TopHighlight",Size=UDim2.new(1,-2,0,1),Position=UDim2.fromOffset(1,1),BackgroundColor3="@Highlight",BackgroundTransparency=.35,ZIndex=object.ZIndex})
    if accent then self:_Frame(object,{Name="AccentEdge",Position=UDim2.new(0,1,1,-1),Size=UDim2.new(1,-2,0,1),BackgroundColor3="@Accent",BackgroundTransparency=.15,ZIndex=object.ZIndex})end
end
function Window:_Shadow(object)
    if not self.Shadows then return end
    local z=math.max(0,object.ZIndex-1)
    local shade=self:_Frame(object,{Name="Shadow",Size=UDim2.fromScale(1,1),BackgroundTransparency=1,ZIndex=z})
    for i=10,1,-1 do
        self:_Frame(shade,{Position=UDim2.fromOffset(-i+2,-i+5),Size=UDim2.new(1,i*2,1,i*2),
            BackgroundColor3=Color3.new(),BackgroundTransparency=.945,ZIndex=z})
    end
    return shade
end
function Window:_List(parent, padding, horizontal)
    return self:_Node("UIListLayout", parent, {Padding=UDim.new(0,padding or 0),
        FillDirection=horizontal and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical,
        SortOrder=Enum.SortOrder.LayoutOrder})
end
function Window:_Hover(button)
    self:_Connect(button.MouseEnter, function() self:_Paint(button,"BackgroundColor3","Hover") end)
    self:_Connect(button.MouseLeave, function() self:_Paint(button,"BackgroundColor3","Raised") end)
end
function Window:_Drag(surface, callback, scope)
    self:_Connect(surface.InputBegan, function(input)
        if not press(input) or self.Capture then return end
        local origin = input.UserInputType == Enum.UserInputType.Touch and Vector2.new(input.Position.X,input.Position.Y) or pointer()
        self.Drag = {Input=input, Origin=origin, Callback=callback, Surface=surface}
        callback(origin, Vector2.zero, true)
    end, scope)
end
function Window:_ClosePopup()
    if self.Drag and self.Drag.Popup then self.Drag = nil end
    for _, c in ipairs(self._popupConnections) do c:Disconnect() end
    table.clear(self._popupConnections)
    self:_ClearPopupItems()
    if self.PopupOwner then self.PopupOwner.RefreshPopup=nil end
    if self.Popup then self.Popup:Destroy() end
    self.Popup, self.PopupAnchor, self.PopupOwner = nil, nil, nil
end
function Window:_ClearPopupItems()
    for _, c in ipairs(self._popupItemConnections) do c:Disconnect() end
    table.clear(self._popupItemConnections)
end
function Window:_Popup(anchor, owner, width, height)
    if self.PopupOwner == owner then self:_ClosePopup() return nil end
    self:_ClosePopup()
    local bounds = self.Layer.AbsoluteSize
    width, height = math.min(width, math.max(160,bounds.X-16)), math.min(height,math.max(100,bounds.Y-16))
    local p, size = anchor.AbsolutePosition-self.Layer.AbsolutePosition, anchor.AbsoluteSize
    local x = math.clamp(p.X+size.X-width,8,math.max(8,bounds.X-width-8))
    local y = p.Y+size.Y+6
    if y+height > bounds.Y-8 then y = p.Y-height-6 end
    y = math.clamp(y,8,math.max(8,bounds.Y-height-8))
    local popup = self:_Frame(self.Layer,{Name="Popup",Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(width,height),BackgroundColor3="@Background",ZIndex=100})
    self:_Border(popup)
    self:_Shadow(popup)
    self.Popup, self.PopupAnchor, self.PopupOwner = popup, anchor, owner
    return popup
end
function Window:SetTheme(theme)
    assert(not self.Destroyed,"Window destroyed")
    for k, v in pairs(theme) do assert(Palette[k] and typeof(v)=="Color3","Invalid theme color: "..tostring(k)) end
    for k, v in pairs(theme) do self.Theme[k] = v end
    for object, properties in pairs(self._themeNodes) do
        if object.Parent then for property, key in pairs(properties) do object[property] = self.Theme[key] end end
    end
    return self
end
function Window:SetVisible(visible)
    assert(not self.Destroyed,"Window destroyed")
    assert(type(visible)=="boolean","Visible must be boolean")
    self.Visible, self.Root.Visible = visible, visible
    self.Drag = nil
    self:_ClosePopup()
    if not visible and self.Modal then self.Modal:Destroy();self.Modal=nil end
    if self.Capture then self.Capture:_CancelCapture() end
    self:_FXRefresh(visible)
    return self
end
function Window:Toggle() return self:SetVisible(not self.Visible) end
function Window:SetSize(width, height)
    assert(finite(width) and finite(height),"Invalid window size")
    local screen = self.Layer.AbsoluteSize
    if self.AutoScale then
        self.Width,self.Height=math.max(380,width),math.max(320,height)
        self.Scale=math.min(1,math.max(1,screen.X-16)/self.Width,math.max(1,screen.Y-16)/self.Height)
        self.RootScale.Scale=self.Scale
    else
        self.Width = math.clamp(width,math.min(380,screen.X-16),math.max(160,screen.X-16))
        self.Height = math.clamp(height,math.min(320,screen.Y-16),math.max(160,screen.Y-16))
    end
    self.Root.Size = UDim2.fromOffset(self.Width,self.Height)
    self:_ClampPosition()
    self:_ClosePopup()
    return self
end
function Window:_ClampPosition()
    local screen = self.Layer.AbsoluteSize
    local p = self.Root.Position
    local scale=self.Scale or 1
    self.Root.Position = UDim2.fromOffset(math.clamp(p.X.Offset,8,math.max(8,screen.X-self.Width*scale-8)),math.clamp(p.Y.Offset,8,math.max(8,screen.Y-self.Height*scale-8)))
end
function Window:Notify(title, message, duration)
    if self.Destroyed then return end
    local toast = self:_Frame(self.Toasts,{Size=UDim2.fromOffset(286,72),BackgroundColor3="@Raised"})
    self:_Border(toast)
    self:_Frame(toast,{Size=UDim2.new(0,2,1,0),BackgroundColor3="@Accent"})
    self:_Text(toast,tostring(title),{Position=UDim2.fromOffset(14,10),Size=UDim2.new(1,-28,0,16)})
    self:_Text(toast,tostring(message or ""),{Position=UDim2.fromOffset(14,31),Size=UDim2.new(1,-28,0,30),TextColor3="@Muted",TextWrapped=true,TextSize=11,TextTruncate=Enum.TextTruncate.None})
    local children = self.Toasts:GetChildren()
    local frames = {} for _, v in ipairs(children) do if v:IsA("Frame") then frames[#frames+1]=v end end
    if #frames>4 then frames[1]:Destroy() end
    task.delay(math.max(1,tonumber(duration) or 4),function() if toast.Parent then toast:Destroy() end end)
    return toast
end
function Window:Destroy()
    if self.Destroyed or self._Destroying then return end
    self._Destroying=true
    self.Visible=false
    if self._keybindLists then
        local lists={}for list in pairs(self._keybindLists)do lists[#lists+1]=list end
        for _,list in ipairs(lists)do list:Destroy()end
    end
    if self._watermarks then
        local marks={}for mark in pairs(self._watermarks)do marks[#marks+1]=mark end
        for _,mark in ipairs(marks)do mark:Destroy()end
    end
    self:_FXDestroy()
    self:_ClosePopup()
    self.Drag = nil
    if self.Capture then self.Capture:_CancelCapture() end
    for _, control in ipairs(self._controls) do
        if control.Type=="Keybind" and control.Active then control:_Activate(false) end
    end
    self.Destroyed = true
    if windowRegistry[self.SingletonKey]==self then windowRegistry[self.SingletonKey]=nil end
    for _, connection in ipairs(self._connections) do connection:Disconnect() end
    table.clear(self._connections)
    self.Screen:Destroy()
    if self.OnUnload then pcall(self.OnUnload) end
end

-- Shared branding layout, including atlas coordinates after texture resizing.
function Window:_CreateBranding(parent,options,properties)
    options=options or {};properties=properties or {}
    local size=options.FontSize or 16
    local height=properties.Height or 22
    local z=properties.ZIndex or parent.ZIndex
    local textService=game:GetService("TextService")
    local name=tostring(options.Name or "")
    local suffix=tostring(options.Suffix or "")
    local function measure(text)return math.ceil(textService:GetTextSize(text,size,self.Font,Vector2.new(4096,height)).X)end
    local nameWidth,suffixWidth=measure(name),measure(suffix)
    local logoSize=options.LogoSize or Vector2.new(size-4,size-2)
    local logoOffset=options.LogoOffset or Vector2.new(0,2)
    local hasLogo=type(options.Logo)=="string"and options.Logo~=""
    local offset=hasLogo and logoSize.X+(options.Gap or 7)or 0
    local suffixGap=(suffix~="" and 2 or 0)
    local width=offset+nameWidth+suffixGap+suffixWidth
    local frame=self:_Frame(parent,{Name="Branding",Position=properties.Position or UDim2.new(),
        Size=UDim2.fromOffset(width,height),BackgroundTransparency=1,ZIndex=z})
    local logo=self:_Node("ImageLabel",frame,{Name="Logo",AnchorPoint=Vector2.new(0,.5),
        Position=UDim2.new(0,logoOffset.X,.5,logoOffset.Y),Size=UDim2.fromOffset(logoSize.X,logoSize.Y),Image=options.Logo or "",
        ImageRectOffset=options.LogoRectOffset or Vector2.zero,ImageRectSize=options.LogoRectSize or Vector2.zero,
        BackgroundTransparency=1,ScaleType=Enum.ScaleType.Fit,Visible=hasLogo,ZIndex=z})
    if options.LogoSourceSize and options.LogoRectSize then
        local function updateRect()
            local texture=logo.ContentImageSize
            local original=options.LogoSourceSize
            if texture.X<=0 or texture.Y<=0 or original.X<=0 or original.Y<=0 then return false end
            local function scaled(v)return Vector2.new(math.floor(v.X*texture.X/original.X+.5),math.floor(v.Y*texture.Y/original.Y+.5))end
            logo.ImageRectOffset=scaled(options.LogoRectOffset or Vector2.zero)
            logo.ImageRectSize=scaled(options.LogoRectSize)
            return true
        end
        self:_Connect(logo:GetPropertyChangedSignal("ContentImageSize"),updateRect)
        if not updateRect()then
            -- ContentImageSize can update without firing its property signal.
            local elapsed,connection=0,nil
            connection=self:_Connect(game:GetService("RunService").Heartbeat,function(dt)
                elapsed+=dt
                if not logo.Parent or updateRect()or elapsed>=10 then connection:Disconnect()end
            end)
        end
    end
    local label=self:_Text(frame,name,{Name="BrandName",AnchorPoint=Vector2.new(0,.5),Position=UDim2.new(0,offset,.5,0),
        Size=UDim2.fromOffset(nameWidth,height),TextSize=size,TextColor3=options.Color or self.Theme.Accent,
        TextYAlignment=Enum.TextYAlignment.Center,TextTruncate=Enum.TextTruncate.None,ZIndex=z})
    if options.Gradient then
        label.TextColor3=Color3.new(1,1,1)
        self:_Node("UIGradient",label,{Color=options.Gradient})
    end
    local tail=self:_Text(frame,suffix,{Name="BrandSuffix",AnchorPoint=Vector2.new(0,.5),
        Position=UDim2.new(0,offset+nameWidth+suffixGap,.5,0),Size=UDim2.fromOffset(suffixWidth,height),
        TextSize=size,TextColor3=options.SuffixColor or Color3.new(1,1,1),TextYAlignment=Enum.TextYAlignment.Center,
        TextTruncate=Enum.TextTruncate.None,ZIndex=z})
    return {Frame=frame,Logo=logo,Name=label,Suffix=tail,Width=width,Options=copy(options)}
end
function Window:SetBranding(options)
    assert(not self.Destroyed,"Window destroyed")
    if self.BrandHeader then self.BrandHeader.Frame:Destroy();self.BrandHeader=nil end
    self.Branding=options and copy(options)or nil
    self.Title.Visible=options==nil
    if options then
        self.BrandHeader=self:_CreateBranding(self.TitleBar,options,{Position=UDim2.fromOffset(18,10),Height=20,ZIndex=self.Title.ZIndex})
    end
    for list in pairs(self._keybindLists or {})do list:SetBranding(self.Branding)end
    for mark in pairs(self._watermarks or {})do mark:SetBranding(self.Branding)end
    return self
end
function Window:CreateWatermark(options)
    assert(not self.Destroyed,"Window destroyed")
    options=options or {}
    local w=self
    local mark={Window=w,Visible=options.Visible~=false,Destroyed=false,_connections={},Text=options.Text or ""}
    local height=options.Height or 32
    mark.Panel=w:_Frame(w.Layer,{Name="Watermark",AnchorPoint=options.AnchorPoint or Vector2.new(1,0),
        Position=options.Position or UDim2.new(1,-16,0,16+GuiService:GetGuiInset().Y),Size=UDim2.fromOffset(180,height),
        BackgroundColor3="@Panel",BackgroundTransparency=.06,ZIndex=230,Visible=mark.Visible})
    w:_Border(mark.Panel);w:_Shadow(mark.Panel);w:_Shade(mark.Panel)
    mark.Accent=w:_Frame(mark.Panel,{Name="Accent",Size=UDim2.new(1,0,0,1),BackgroundColor3="@Accent",ZIndex=231})
    mark.Divider=w:_Frame(mark.Panel,{Name="Divider",AnchorPoint=Vector2.new(0,.5),Position=UDim2.new(0,0,.5,0),
        Size=UDim2.fromOffset(1,12),BackgroundColor3="@Border",ZIndex=232})
    mark.Details=w:_Text(mark.Panel,"",{Name="Details",AnchorPoint=Vector2.new(0,.5),Position=UDim2.new(0,0,.5,0),
        Size=UDim2.fromOffset(100,height),TextSize=options.TextSize or 11,TextColor3="@Text",ZIndex=232,
        TextYAlignment=Enum.TextYAlignment.Center,TextTruncate=Enum.TextTruncate.None})
    function mark:Refresh()
        if self.Destroyed then return self end
        local parts={}
        if self.Text~=""then parts[#parts+1]=self.Text end
        if options.ShowFPS~=false then parts[#parts+1]=tostring(self.FPS or 0).." fps"end
        if options.ShowPing~=false then parts[#parts+1]=(self.Ping and tostring(self.Ping)or "--").." ms"end
        local text=table.concat(parts,"  ·  ")
        self.Details.Text=text
        local width=math.ceil(game:GetService("TextService"):GetTextSize(text,self.Details.TextSize,w.Font,Vector2.new(4096,height)).X)
        local brandWidth=self.Branding and self.Branding.Width or 0
        local hasDetails=text~=""
        self.Divider.Visible=hasDetails and brandWidth>0
        self.Divider.Position=UDim2.new(0,12+brandWidth+9,.5,0)
        local x=12+brandWidth+(hasDetails and brandWidth>0 and 19 or 0)
        self.Details.Position=UDim2.new(0,x,.5,0);self.Details.Size=UDim2.fromOffset(width,height)
        self.Panel.Size=UDim2.fromOffset(math.max(40,x+width+12),height)
        self.Panel.Visible=self.Visible
        return self
    end
    function mark:SetBranding(branding)
        if self.Branding then self.Branding.Frame:Destroy()end
        local b=copy(branding or {Name=options.Title or w.Title.Text,Color=w.Theme.Accent})
        b.FontSize=options.FontSize or 14;b.LogoSize=options.LogoSize or Vector2.new(11,13)
        self.Branding=w:_CreateBranding(self.Panel,b,{Position=UDim2.fromOffset(12,(height-20)/2),Height=20,ZIndex=232})
        local color=w._themeNodes[self.Accent];if color then color.BackgroundColor3=nil end
        self.Accent.BackgroundColor3=b.Gradient and Color3.new(1,1,1)or b.Color or w.Theme.Accent
        local old=self.Accent:FindFirstChildOfClass("UIGradient");if old then old:Destroy()end
        if b.Gradient then w:_Node("UIGradient",self.Accent,{Color=b.Gradient})end
        return self:Refresh()
    end
    function mark:SetText(value)assert(not self.Destroyed,"Watermark destroyed");self.Text=tostring(value);return self:Refresh()end
    function mark:SetVisible(value)assert(type(value)=="boolean","Visible must be boolean");assert(not self.Destroyed,"Watermark destroyed");self.Visible=value;return self:Refresh()end
    function mark:SetPosition(value)assert(typeof(value)=="UDim2","Position must be UDim2");assert(not self.Destroyed,"Watermark destroyed");self.Panel.Position=value;return self end
    function mark:Destroy()
        if self.Destroyed then return end
        self.Destroyed=true
        for _,connection in ipairs(self._connections)do connection:Disconnect()end
        table.clear(self._connections);self.Panel:Destroy();w._watermarks[self]=nil
    end
    w._watermarks=w._watermarks or {};w._watermarks[mark]=true
    mark:SetBranding(options.Branding or w.Branding)
    local elapsed,frames=0,0
    w:_Connect(game:GetService("RunService").Heartbeat,function(dt)
        elapsed+=dt;frames+=1
        if elapsed<1 then return end
        mark.FPS=math.floor(frames/elapsed+.5);elapsed,frames=0,0
        if options.ShowPing~=false then
            local ok,ping=pcall(function()return game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue()end)
            mark.Ping=ok and finite(ping)and math.floor(ping+.5)or nil
        end
        mark:Refresh()
    end,mark._connections)
    return mark
end
function Window:SetFooterVersion(text,options)
    assert(not self.Destroyed,"Window destroyed")
    options=options or {}
    if self.VersionLabel then self.VersionLabel:Destroy();self.VersionSeparator:Destroy();self.VersionLabel=nil end
    self._versionFooterPosition=self._versionFooterPosition or self.Footer.Position
    self._versionFooterSize=self._versionFooterSize or self.Footer.Size
    if text==nil then self.Footer.Position=self._versionFooterPosition;self.Footer.Size=self._versionFooterSize;return self end
    local size=options.TextSize or 13
    local width=math.ceil(game:GetService("TextService"):GetTextSize(tostring(text),size,self.Font,Vector2.new(4096,16)).X)
    local right=options.Side~="Left"
    self.VersionLabel=self:_Text(self.Root,tostring(text),{Name="Version",AnchorPoint=right and Vector2.new(1,0)or Vector2.zero,
        Position=right and UDim2.new(1,-18,1,-25)or UDim2.new(0,18,1,-25),
        Size=UDim2.fromOffset(width,20),TextSize=size,TextColor3=options.Gradient and Color3.new(1,1,1)or options.Color or self.Theme.Accent,
        TextTruncate=Enum.TextTruncate.None})
    if options.Gradient then self:_Node("UIGradient",self.VersionLabel,{Color=options.Gradient})end
    self.VersionSeparator=self:_Frame(self.Root,{Name="VersionSeparator",Position=right and UDim2.new(1,-18-width-8,1,-20)or UDim2.new(0,18+width+7,1,-20),
        Size=UDim2.fromOffset(1,8),BackgroundColor3="@Border"})
    self.Footer.Position=right and self._versionFooterPosition or UDim2.new(0,18+width+15,1,-24)
    self.Footer.Size=UDim2.new(1,-55-width-15,0,16)
    return self
end

-- Optional keybind HUD, independent from menu visibility, owned by the window.
function Window:CreateKeybindList(options)
    assert(not self.Destroyed,"Window destroyed")
    options=options or {}
    local w=self
    local width=math.clamp(options.Width or 222,160,400)
    local list={Window=w,Entries={},Visible=options.Visible~=false,Destroyed=false,VisibleCount=0,_connections={}}
    list.Panel=w:_Frame(w.Layer,{Name="KeybindList",Position=options.Position or UDim2.new(0,16,.5,0),
        AnchorPoint=options.AnchorPoint or Vector2.new(0,.5),Size=UDim2.fromOffset(width,64),
        BackgroundColor3="@Panel",BackgroundTransparency=.08,ZIndex=220})
    w:_Border(list.Panel);w:_Shadow(list.Panel)
    w:_Frame(list.Panel,{Name="Accent",Size=UDim2.new(1,0,0,1),BackgroundColor3="@Accent",ZIndex=221})
    list.Title=w:_Text(list.Panel,options.Title or "KEYBINDS",{Position=UDim2.fromOffset(12,8),
        Size=UDim2.new(1,-24,0,18),TextSize=11,TextColor3="@Accent",ZIndex=222})
    list.MenuLabel=w:_Text(list.Panel,"",{Name="MenuShortcut",Position=UDim2.fromOffset(12,37),
        Size=UDim2.new(1,-24,0,18),TextSize=10,TextColor3="@Muted",Visible=options.ShowMenu~=false,ZIndex=222})
    local aliases={MB1="Mouse 1",MB2="Mouse 2",LeftControl="L Ctrl",RightControl="R Ctrl",
        LeftShift="L Shift",RightShift="R Shift",LeftAlt="L Alt",RightAlt="R Alt",None="Unbound",Unknown="Unbound"}
    local function friendly(key)return aliases[key]or key end
    local function resolve(control)
        if type(control)=="string"then control=w.Options[control]end
        return control
    end
    function list:Add(info)
        assert(not self.Destroyed,"Keybind list destroyed")
        assert(type(info)=="table","Entry options required")
        local bind=resolve(info.Keybind)
        assert(bind and bind.Type=="Keybind"and bind.Window==w,"Entry requires a keybind from this window")
        local toggle=resolve(info.Toggle)
        if toggle then assert(toggle.Type=="Toggle"and toggle.Window==w,"Invalid entry toggle")end
        if info.IsActive then assert(type(info.IsActive)=="function","IsActive must be a function")end
        local entry={Keybind=bind,Toggle=toggle,IsActive=info.IsActive,Text=info.Text or bind.Label.Text}
        entry.Row=w:_Frame(self.Panel,{Size=UDim2.new(1,-24,0,20),Position=UDim2.fromOffset(12,32),BackgroundTransparency=1,ZIndex=221})
        entry.Label=w:_Text(entry.Row,entry.Text,{Size=UDim2.new(1,-90,1,0),TextSize=11,ZIndex=222})
        entry.Key=w:_Text(entry.Row,"",{Position=UDim2.new(1,-88,0,0),Size=UDim2.fromOffset(64,20),TextXAlignment=Enum.TextXAlignment.Right,TextSize=10,TextColor3="@Muted",ZIndex=222})
        entry.Status=w:_Text(entry.Row,"ON",{Position=UDim2.new(1,-22,0,0),Size=UDim2.fromOffset(22,20),TextXAlignment=Enum.TextXAlignment.Right,TextSize=10,TextColor3="@Accent",ZIndex=222})
        self.Entries[#self.Entries+1]=entry
        self:Refresh()
        return entry
    end
    function list:Remove(entry)
        assert(not self.Destroyed,"Keybind list destroyed")
        local index=table.find(self.Entries,entry)
        if index then entry.Row:Destroy();table.remove(self.Entries,index);self:Refresh()end
    end
    function list:Refresh()
        if self.Destroyed or w.Destroyed then return end
        self.Panel.Visible=self.Visible
        local count=0
        for _,entry in ipairs(self.Entries)do
            local active
            if entry.IsActive then local ok,value=pcall(entry.IsActive);active=ok and value==true
            elseif entry.Toggle then active=entry.Toggle:Get()==true
            else active=entry.Keybind.Active==true end
            active=active and not entry.Keybind.Disabled and not (entry.Keybind.ParentControl and entry.Keybind.ParentControl.Disabled)
            entry.Row.Visible=active==true
            if active then
                entry.Row.Position=UDim2.fromOffset(12,32+count*21)
                entry.Key.Text="["..friendly(entry.Keybind:Get()).."]"
                count+=1
            end
        end
        self.VisibleCount=count
        local menu=resolve(options.MenuKey)
        local key=menu and menu:Get()or w.ToggleKey.Name
        self.MenuLabel.Text="["..friendly(key).."] "..(options.MenuText or "Menu")
        self.MenuLabel.Position=UDim2.fromOffset(12,37+count*21)
        self.Panel.Size=UDim2.fromOffset(width,(options.ShowMenu~=false and 64 or 40)+count*21)
    end
    function list:SetVisible(value)
        assert(type(value)=="boolean","Visible must be boolean")
        assert(not self.Destroyed,"Keybind list destroyed")
        self.Visible=value;self:Refresh();return self
    end
    function list:SetBranding(branding)
        if self.Branding then self.Branding.Frame:Destroy();self.Branding=nil end
        self.Title.Visible=branding==nil
        if branding then
            local b=copy(branding)
            b.FontSize=options.TitleTextSize or math.min(16,b.FontSize or 16)
            b.LogoSize=options.LogoSize or Vector2.new(12,14)
            self.Branding=w:_CreateBranding(self.Panel,b,{Position=UDim2.fromOffset(12,7),Height=22,ZIndex=222})
        end
        return self
    end
    function list:SetTitle(value)assert(not self.Destroyed,"Keybind list destroyed");self.Title.Text=tostring(value);return self end
    function list:SetPosition(value)assert(typeof(value)=="UDim2","Position must be UDim2");assert(not self.Destroyed,"Keybind list destroyed");self.Panel.Position=value;return self end
    function list:Destroy()
        if self.Destroyed then return end
        self.Destroyed=true
        for _,connection in ipairs(self._connections)do connection:Disconnect()end
        table.clear(self._connections)
        self.Panel:Destroy();table.clear(self.Entries)
        w._keybindLists[self]=nil
    end
    w._keybindLists=w._keybindLists or {};w._keybindLists[list]=true
    local elapsed=0
    w:_Connect(game:GetService("RunService").Heartbeat,function(dt)
        elapsed+=dt
        if elapsed>=.1 then elapsed=0;if list.Visible then list:Refresh()end end
    end,list._connections)
    list:SetBranding(options.Branding or w.Branding)
    list:Refresh()
    return list
end

-- All atmosphere objects belong to this window; none touches game lighting.
local EffectDefaults={Dim=true,DimAmount=.42,Vignette=true,Glow=true,GlowStrength=.65,
    GlowPulse=true,Particles=true,ParticleCount=32,ParticleSpeed=65,Cursor=true,
    CursorStyle="Arrow",CursorSize=16,CursorTrail=true,ClickRipples=true,ReducedMotion=false}
local EffectRanges={DimAmount={0,.8},GlowStrength={0,1},ParticleCount={0,64},
    ParticleSpeed={10,200},CursorSize={10,24}}
local function normalizedEffects(values,base)
    assert(type(values)=="table","Effects must be a table")
    local out=copy(base or EffectDefaults)
    for key,value in pairs(values)do
        assert(EffectDefaults[key]~=nil,"Unknown effect: "..tostring(key))
        if EffectRanges[key] then
            local range=EffectRanges[key]
            assert(finite(value)and value>=range[1]and value<=range[2],"Invalid effect amount: "..key)
            if key=="ParticleCount"then assert(value%1==0,"ParticleCount must be an integer")end
        elseif key=="CursorStyle"then assert(value=="Arrow"or value=="Cross","Invalid cursor style")
        else assert(type(value)=="boolean","Effect toggle must be boolean: "..key)end
        out[key]=value
    end
    return out
end
local cursorUsers=setmetatable({},{__mode="k"})
local cursorBaseline
local function cursorClaim(window,enabled)
    if enabled then
        if not cursorUsers[window]then
            if not next(cursorUsers)then cursorBaseline=Input.MouseIconEnabled end
            cursorUsers[window]=true
        end
        Input.MouseIconEnabled=false
    elseif cursorUsers[window]then
        cursorUsers[window]=nil
        if not next(cursorUsers)then
            if Input.MouseIconEnabled==false and cursorBaseline~=nil then Input.MouseIconEnabled=cursorBaseline end
            cursorBaseline=nil
        end
    end
end
function Window:_FXBackdrop()
    self.Effects=normalizedEffects(self._effectOptions or {})
    self._fxTime=0;self._fxFocused=true;self._fxRandom=Random.new()
    self._fxRipples={};self._fxTrail={};self._fxParticles={}
    self.Backdrop=self:_Frame(self.Layer,{Name="MenuBackdrop",Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.new(),BackgroundTransparency=1,ZIndex=0})
    self._fxVignette=self:_Frame(self.Layer,{Name="Vignette",Size=UDim2.fromScale(1,1),BackgroundTransparency=1,ZIndex=0})
    local edges={
        {UDim2.fromScale(0,0),UDim2.new(1,0,.18,0),90},
        {UDim2.fromScale(0,.82),UDim2.new(1,0,.18,0),270},
        {UDim2.fromScale(0,0),UDim2.new(.12,0,1,0),0},
        {UDim2.fromScale(.88,0),UDim2.new(.12,0,1,0),180},
    }
    for _,edge in ipairs(edges)do
        local frame=self:_Frame(self._fxVignette,{Position=edge[1],Size=edge[2],BackgroundColor3=Color3.new(),BackgroundTransparency=.6,ZIndex=0})
        self:_Node("UIGradient",frame,{Rotation=edge[3],Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(1,1)})})
    end
    self.ParticleLayer=self:_Frame(self.Layer,{Name="FallingLights",Size=UDim2.fromScale(1,1),BackgroundTransparency=1,ClipsDescendants=true,ZIndex=0})
end
function Window:_FXMakeParticles()
    self.ParticleLayer:ClearAllChildren()
    table.clear(self._fxParticles)
    for _=1,self.Effects.ParticleCount do
        local rng=self._fxRandom
        local length=rng:NextNumber(7,17)
        local streak=self:_Frame(self.ParticleLayer,{Name="Light",Size=UDim2.fromOffset(1,length),BackgroundColor3="@Accent",BackgroundTransparency=.25,ZIndex=0})
        self:_Node("UIGradient",streak,{Rotation=90,Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(1,0)})})
        self:_Frame(streak,{Position=UDim2.new(0,-.5,1,-2),Size=UDim2.fromOffset(2,2),BackgroundColor3="@Accent",BackgroundTransparency=.1,ZIndex=0})
        self._fxParticles[#self._fxParticles+1]={Gui=streak,X=rng:NextNumber(0,1),Y=rng:NextNumber(-.1,1),Speed=rng:NextNumber(.5,1.4),Phase=rng:NextNumber(0,math.pi*2)}
    end
end
function Window:_FXInitialize()
    self._fxGlow=self:_Frame(self.Root,{Name="AmbientGlow",Size=UDim2.fromScale(1,1),BackgroundTransparency=1,ZIndex=0})
    self._fxGlowLayers={}
    for i=14,1,-1 do
        local pad=i*2
        local frame=self:_Frame(self._fxGlow,{Position=UDim2.fromOffset(-pad,-pad),Size=UDim2.new(1,pad*2,1,pad*2),BackgroundColor3="@Accent",BackgroundTransparency=1,ZIndex=0})
        self._fxGlowLayers[#self._fxGlowLayers+1]={Gui=frame,Weight=.019*(1-i/18)}
    end
    self.CursorGui=self:_Frame(self.Layer,{Name="MenuCursor",Size=UDim2.fromOffset(16,20),BackgroundTransparency=1,ZIndex=1000})
    -- Built-in antialiased arrow: its hotspot is at the texture center.
    -- No upload or external image dependency is required.
    self._fxArrow=self:_Node("ImageLabel",self.CursorGui,{Name="Arrow",Image="rbxasset://textures/Cursors/KeyboardMouse/ArrowFarCursor.png",
        Position=UDim2.fromOffset(-32,-32),Size=UDim2.fromOffset(64,64),BackgroundTransparency=1,ZIndex=1001})
    self._fxCross=self:_Frame(self.CursorGui,{Size=UDim2.fromOffset(16,16),BackgroundTransparency=1,ZIndex=1001})
    self:_Frame(self._fxCross,{Position=UDim2.fromOffset(1,6),Size=UDim2.fromOffset(14,3),BackgroundColor3=Color3.new(),ZIndex=1002})
    self:_Frame(self._fxCross,{Position=UDim2.fromOffset(6,1),Size=UDim2.fromOffset(3,14),BackgroundColor3=Color3.new(),ZIndex=1002})
    self:_Frame(self._fxCross,{Position=UDim2.fromOffset(2,7),Size=UDim2.fromOffset(12,1),BackgroundColor3="@Accent",ZIndex=1003})
    self:_Frame(self._fxCross,{Position=UDim2.fromOffset(7,2),Size=UDim2.fromOffset(1,12),BackgroundColor3="@Accent",ZIndex=1003})
    self:_Node("UIScale",self.CursorGui,{Name="CursorScale",Scale=1})
    for _=1,10 do
        local dot=self:_Frame(self.Layer,{Name="CursorTrail",Size=UDim2.fromOffset(2,2),AnchorPoint=Vector2.new(.5,.5),BackgroundColor3="@Accent",BackgroundTransparency=1,Visible=false,ZIndex=999})
        self:_Node("UICorner",dot,{CornerRadius=UDim.new(1,0)})
        self._fxTrail[#self._fxTrail+1]={Gui=dot,Age=1}
    end
    self._fxTrailIndex=1;self._fxTrailClock=0
    self:_FXMakeParticles()
    self:_Connect(Input.WindowFocused,function()self._fxFocused=true;self:_FXRefresh()end)
    self:_FXRefresh(true)
end
function Window:_FXGlowTick(time)
    local pulse=self.Effects.GlowPulse and not self.Effects.ReducedMotion and (.8+.2*math.sin(time*1.7))or 1
    for _,layer in ipairs(self._fxGlowLayers)do layer.Gui.BackgroundTransparency=1-self.Effects.GlowStrength*pulse*layer.Weight end
end
function Window:_FXCursorTick(dt)
    local p=pointer()-self.Layer.AbsolutePosition
    local size=self.Layer.AbsoluteSize
    local show=self.Visible and self._fxFocused and self.Effects.Cursor and Input.MouseEnabled
        and not Input:GetFocusedTextBox()and p.X>=0 and p.Y>=0 and p.X<=size.X and p.Y<=size.Y
    self.CursorGui.Visible=show==true
    cursorClaim(self,show)
    if show then
        self.CursorGui.Position=UDim2.fromOffset(p.X,p.Y)
        self._fxTrailClock+=dt
        if self.Effects.CursorTrail and not self.Effects.ReducedMotion and self._fxTrailClock>.025
            and self._fxLastPointer and (p-self._fxLastPointer).Magnitude>2 then
            self._fxTrailClock=0
            local item=self._fxTrail[self._fxTrailIndex]
            item.Age=0;item.Gui.Position=UDim2.fromOffset(p.X,p.Y)
            self._fxTrailIndex=self._fxTrailIndex%#self._fxTrail+1
        end
        self._fxLastPointer=p
    else
        self._fxLastPointer=nil
    end
    for _,item in ipairs(self._fxTrail)do
        item.Age+=dt
        item.Gui.Visible=show and self.Effects.CursorTrail and not self.Effects.ReducedMotion and item.Age<.14
        item.Gui.BackgroundTransparency=.65+.35*math.clamp(item.Age/.14,0,1)
    end
end
function Window:_FXStep(dt)
    dt=math.clamp(dt,0,.1)
    self._fxTime+=dt
    self:_FXGlowTick(self._fxTime)
    if self.Effects.Particles and not self.Effects.ReducedMotion then
        local size=self.ParticleLayer.AbsoluteSize
        for _,item in ipairs(self._fxParticles)do
            item.Y+=dt*self.Effects.ParticleSpeed*item.Speed/math.max(1,size.Y)
            if item.Y>1.05 then item.Y=-.1;item.X=self._fxRandom:NextNumber()end
            item.Gui.Position=UDim2.fromOffset(item.X*size.X+math.sin(self._fxTime*.5+item.Phase)*8,item.Y*size.Y)
        end
    end
    self:_FXCursorTick(dt)
    for i=#self._fxRipples,1,-1 do
        local ripple=self._fxRipples[i];ripple.Age+=dt
        local progress=math.min(1,ripple.Age/.35)
        ripple.Gui.Size=UDim2.fromOffset(4+progress*34,4+progress*34)
        ripple.Stroke.Transparency=progress
        if progress>=1 then ripple.Gui:Destroy();table.remove(self._fxRipples,i)end
    end
    self:_FXEnsureLoop()
end
function Window:_FXClick(input)
    if not self.Visible or not self.Effects.ClickRipples or self.Effects.ReducedMotion or not press(input)then return end
    local position=input.UserInputType==Enum.UserInputType.Touch and Vector2.new(input.Position.X,input.Position.Y)or pointer()
    if not hit(self.Root,position)and not (self.Popup and hit(self.Popup,position))then return end
    local ring=self:_Frame(self.Layer,{Name="ClickRipple",Position=UDim2.fromOffset(position.X-self.Layer.AbsolutePosition.X,position.Y-self.Layer.AbsolutePosition.Y),
        Size=UDim2.fromOffset(4,4),AnchorPoint=Vector2.new(.5,.5),BackgroundTransparency=1,ZIndex=700})
    self:_Node("UICorner",ring,{CornerRadius=UDim.new(1,0)})
    local stroke=self:_Border(ring,"Accent")
    self._fxRipples[#self._fxRipples+1]={Gui=ring,Stroke=stroke,Age=0}
    if #self._fxRipples>6 then self._fxRipples[1].Gui:Destroy();table.remove(self._fxRipples,1)end
    self:_FXEnsureLoop()
end
function Window:_FXEnsureLoop()
    local e=self.Effects
    local animate=self.Visible and self._fxFocused and (e.Cursor or not e.ReducedMotion and (e.Particles or e.Glow and e.GlowPulse)or #self._fxRipples>0)
    if animate and not self._fxConnection then
        self._fxConnection=game:GetService("RunService").RenderStepped:Connect(function(dt)if not self.Destroyed then self:_FXStep(dt)end end)
    elseif not animate and self._fxConnection then self._fxConnection:Disconnect();self._fxConnection=nil end
end
function Window:_FXRefresh(opening)
    if not self.CursorGui then return end
    local e=self.Effects
    if self._fxDimTween then self._fxDimTween:Cancel();self._fxDimTween=nil end
    self.Backdrop.Visible=self.Visible and e.Dim
    self._fxVignette.Visible=self.Visible and e.Vignette
    self._fxGlow.Visible=self.Visible and e.Glow
    self.ParticleLayer.Visible=self.Visible and e.Particles and not e.ReducedMotion
    local transparency=1-e.DimAmount
    if opening and self.Visible and e.Dim and not e.ReducedMotion then
        self.Backdrop.BackgroundTransparency=1
        self._fxDimTween=game:GetService("TweenService"):Create(self.Backdrop,TweenInfo.new(.18),{BackgroundTransparency=transparency})
        self._fxDimTween:Play()
    else self.Backdrop.BackgroundTransparency=transparency end
    self._fxArrow.Visible=e.CursorStyle=="Arrow";self._fxCross.Visible=e.CursorStyle=="Cross"
    self.CursorGui.AnchorPoint=e.CursorStyle=="Cross"and Vector2.new(.5,.5)or Vector2.zero
    self.CursorGui.CursorScale.Scale=e.CursorSize/16
    self:_FXGlowTick(self._fxTime)
    self:_FXCursorTick(0)
    self:_FXEnsureLoop()
    if not self.Visible then
        for _,ripple in ipairs(self._fxRipples)do ripple.Gui:Destroy()end
        table.clear(self._fxRipples)
        for _,item in ipairs(self._fxTrail)do item.Gui.Visible=false;item.Age=1 end
    end
end
function Window:SetEffects(values)
    assert(not self.Destroyed,"Window destroyed")
    local normalized=normalizedEffects(values,self.Effects)
    local rebuild=normalized.ParticleCount~=self.Effects.ParticleCount
    self.Effects=normalized
    if rebuild then self:_FXMakeParticles()end
    self:_FXRefresh()
    return self
end
function Window:GetEffects()return copy(self.Effects)end
function Window:_FXDestroy()
    if self._fxConnection then self._fxConnection:Disconnect();self._fxConnection=nil end
    if self._fxDimTween then self._fxDimTween:Cancel();self._fxDimTween=nil end
    cursorClaim(self,false)
end

function Library:CreateWindow(options)
    options = options or {}
    local singletonKey=options.SingletonKey or "default"
    if options.AllowMultiple~=true then
        local previous=windowRegistry[singletonKey]
        if previous and not previous.Destroyed then previous:Destroy()end
        if singletonKey=="default"then
            local legacy=runtimeEnv.NocturneDemo
            if legacy and not legacy.Destroyed and type(legacy.Destroy)=="function"then legacy:Destroy()end
        end
    end
    local parent = options.Parent or Players.LocalPlayer:WaitForChild("PlayerGui")
    local self = setmetatable({Theme=copy(Palette),Font=options.Font or Enum.Font.Code,
        Flags={},Options={},Tabs={},Visible=true,Destroyed=false,_connections={},_popupConnections={},_popupItemConnections={},
        _themeNodes=setmetatable({},{__mode="k"}),_controls={},_nextFlag=0,Storage=options.Storage,
        ToggleKey=options.ToggleKey or Enum.KeyCode.Insert,OnUnload=options.OnUnload,
        Shading=options.Shading~=false,Shadows=options.Shadows~=false,Checkmarks=options.Checkmarks==true,
        CompactHeader=options.CompactHeader~=false,_effectOptions=options.Effects,
        Scrollable=options.Scrollable~=false,CompactControls=options.CompactControls==true,
        AutoScale=options.AutoScale==true,SingletonKey=singletonKey},Window)
    if options.Theme then for k,v in pairs(options.Theme) do assert(Palette[k] and typeof(v)=="Color3","Invalid theme");self.Theme[k]=v end end
    if options.Accent then assert(typeof(options.Accent)=="Color3");self.Theme.Accent=options.Accent end
    self.Screen = self:_Node("ScreenGui",parent,{Name=options.Name or "Nocturne",ResetOnSpawn=false,IgnoreGuiInset=true,DisplayOrder=options.DisplayOrder or 80,ZIndexBehavior=Enum.ZIndexBehavior.Global})
    self.Layer = self:_Frame(self.Screen,{Name="Layer",Size=UDim2.fromScale(1,1),BackgroundTransparency=1})
    self:_FXBackdrop()
    self.Width,self.Height = options.Width or 760,options.Height or 580
    local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280,720)
    self.Root = self:_Frame(self.Layer,{Name="Window",Size=UDim2.fromOffset(self.Width,self.Height),Position=UDim2.fromOffset(math.max(8,(viewport.X-self.Width)/2),math.max(8,(viewport.Y-self.Height)/2)),BackgroundColor3="@Background",Active=true})
    if self.AutoScale then
        self.RootScale=self:_Node("UIScale",self.Root,{Scale=1})
        self:SetSize(self.Width,self.Height)
        self.Root.Position=UDim2.fromOffset(math.max(8,(viewport.X-self.Width*self.Scale)/2),math.max(8,(viewport.Y-self.Height*self.Scale)/2))
    end
    self:_Border(self.Root)
    self:_Shadow(self.Root)
    local inset=self:_Frame(self.Root,{Name="InsetBorder",Position=UDim2.fromOffset(7,7),Size=UDim2.new(1,-14,1,-14),BackgroundTransparency=1})
    self:_Border(inset,"Highlight")
    self:_Frame(self.Root,{Position=UDim2.fromOffset(8,8),Size=UDim2.new(1,-16,0,1),BackgroundColor3="@Accent"})
    local compact=self.CompactHeader
    local titlebar = self:_Frame(self.Root,{Size=UDim2.new(1,0,0,compact and 29 or 52),Position=UDim2.fromOffset(0,2),BackgroundTransparency=1,Active=true})
    self.TitleBar=titlebar
    self.Title=self:_Text(titlebar,options.Title or "NOCTURNE",{Position=UDim2.fromOffset(18,compact and 8 or 9),Size=UDim2.new(1,-125,0,18),TextSize=compact and 10 or 16,TextColor3=compact and "@Muted" or "@Text"})
    self:_Text(titlebar,options.Subtitle or "INTERFACE LIBRARY / 1.2",{Position=UDim2.fromOffset(18,29),Size=UDim2.new(1,-125,0,14),TextSize=10,TextColor3="@Muted",Visible=not compact})
    local hide = self:_Text(titlebar,"−",{Position=UDim2.new(1,-65,0,compact and 8 or 12),Size=UDim2.fromOffset(20,compact and 18 or 26),TextXAlignment=Enum.TextXAlignment.Center,BackgroundTransparency=0,BackgroundColor3="@Raised"},"TextButton")
    local close = self:_Text(titlebar,"×",{Position=UDim2.new(1,-40,0,compact and 8 or 12),Size=UDim2.fromOffset(20,compact and 18 or 26),TextXAlignment=Enum.TextXAlignment.Center,BackgroundTransparency=0,BackgroundColor3="@Raised"},"TextButton")
    self:_Shade(hide);self:_Shade(close)
    self:_Hover(hide);self:_Hover(close)
    self:_Connect(hide.Activated,function() self:SetVisible(false) end)
    self:_Connect(close.Activated,function() if options.DestroyOnClose then self:Destroy() else self:SetVisible(false) end end)
    self._tabY=compact and 35 or 60
    self._subY=self._tabY+39
    self._pageY=self._tabY+44
    self._subPageY=self._tabY+85
    self.TabBar = self:_Frame(self.Root,{Position=UDim2.fromOffset(16,self._tabY),Size=UDim2.new(1,-32,0,32),BackgroundTransparency=1,ClipsDescendants=true})
    self:_List(self.TabBar,1,true)
    self.SubBar = self:_Frame(self.Root,{Position=UDim2.fromOffset(16,self._subY),Size=UDim2.new(1,-32,0,38),Visible=false,BackgroundTransparency=1,ClipsDescendants=true})
    self:_Connect(self.SubBar:GetPropertyChangedSignal("AbsoluteSize"),function()self:_FitSubTabs()end)
    self.PageHost = self:_Frame(self.Root,{Name="Pages",Position=UDim2.fromOffset(16,self._pageY),Size=UDim2.new(1,-32,1,-self._pageY-38),BackgroundTransparency=1})
    self:_Connect(self.TabBar:GetPropertyChangedSignal("AbsoluteSize"),function()self:_FitTabs()end)
    self:_Frame(self.Root,{Position=UDim2.new(0,16,1,-31),Size=UDim2.new(1,-32,0,1),BackgroundColor3="@Border"})
    self.Footer = self:_Text(self.Root,options.Footer or "NOCTURNE  /  INSERT TO TOGGLE",{Position=UDim2.new(0,18,1,-24),Size=UDim2.new(1,-55,0,16),TextSize=10,TextColor3="@Muted"})
    self._footerText = self.Footer.Text
    local resize = self:_Text(self.Root,"◢",{Position=UDim2.new(1,-24,1,-25),Size=UDim2.fromOffset(22,22),TextColor3="@Muted",Active=true},"TextButton")
    resize.Visible=options.Resizable~=false
    local startPos,startSize
    self:_Drag(titlebar,function(_,delta,begin)
        if begin then self:_ClosePopup();startPos=self.Root.Position end
        self.Root.Position = UDim2.fromOffset(startPos.X.Offset+delta.X,startPos.Y.Offset+delta.Y)
        self:_ClampPosition()
    end)
    self:_Drag(resize,function(_,delta,begin)
        if begin then startSize=Vector2.new(self.Width,self.Height) end
        self:SetSize(startSize.X+delta.X,startSize.Y+delta.Y)
    end)
    self.Toasts = self:_Frame(self.Layer,{Position=UDim2.new(1,-302,1,-18),AnchorPoint=Vector2.new(0,1),Size=UDim2.fromOffset(286,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,ZIndex=200})
    self:_List(self.Toasts,8)
    self._HandleInputChanged=function(input)
        local drag=self.Drag
        if not drag then return end
        if not self.Visible or not drag.Surface.Parent then self.Drag=nil;return end
        if input.UserInputType==Enum.UserInputType.MouseMovement and drag.Input.UserInputType==Enum.UserInputType.MouseButton1 then
            if not Input:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then self.Drag=nil;return end
            local p=pointer();drag.Callback(p,p-drag.Origin,false)
        elseif input==drag.Input and input.UserInputType==Enum.UserInputType.Touch then
            local p=Vector2.new(input.Position.X,input.Position.Y);drag.Callback(p,p-drag.Origin,false)
        end
    end
    self:_Connect(Input.InputChanged,self._HandleInputChanged)
    self._HandleInputEnded=function(input)
        if self.Drag and (input==self.Drag.Input or input.UserInputType==Enum.UserInputType.MouseButton1 and self.Drag.Input.UserInputType==Enum.UserInputType.MouseButton1) then self.Drag=nil end
        local key=inputKey(input)
        for _, c in ipairs(self._controls) do if c.Type=="Keybind" and c.Value.Mode=="Hold" and c.Value.Key==key then c:_Activate(false) end end
    end
    self:_Connect(Input.InputEnded,self._HandleInputEnded)
    self:_Connect(Input.WindowFocusReleased,function()
        self.Drag=nil
        for _,c in ipairs(self._controls)do if c.Type=="Keybind" and c.Value.Mode=="Hold" then c:_Activate(false) end end
        self._fxFocused=false;self:_FXRefresh()
    end)
    self._HandleInputBegan=function(input,processed)
        self:_FXClick(input)
        local key=inputKey(input)
        if self.Capture then
            if press(input) then
                local p=input.UserInputType==Enum.UserInputType.Touch and Vector2.new(input.Position.X,input.Position.Y) or pointer()
                if hit(self.Capture.Button,p) then return end
                if self.Capture.MenuButton and hit(self.Capture.MenuButton,p) then self.Capture:_CancelCapture();return end
            end
            if key=="Escape" then self.Capture:_CancelCapture()
            elseif key then local c=self.Capture;c:_CancelCapture();c:Set(key=="Backspace" and "None" or key,c.Value.Mode) end
            return
        end
        if self.Popup and press(input) then
            local p=input.UserInputType==Enum.UserInputType.Touch and Vector2.new(input.Position.X,input.Position.Y) or pointer()
            if not hit(self.Popup,p) and not hit(self.PopupAnchor,p) then self:_ClosePopup() end
        end
        if processed or Input:GetFocusedTextBox() then return end
        if self.Modal then
            if input.KeyCode==Enum.KeyCode.Escape then self.Modal:Destroy();self.Modal=nil end
            return
        end
        if input.KeyCode==Enum.KeyCode.Escape and self.Popup then self:_ClosePopup() return end
        if input.KeyCode==self.ToggleKey then self:Toggle() return end
        for _, c in ipairs(self._controls) do
            if c.Type=="Keybind" and c.Value.Key==key and key~="None" and not c.Disabled and not (c.ParentControl and c.ParentControl.Disabled) then
                if c.Value.Mode=="Toggle" then c:_Activate(not c.Active)
                elseif c.Value.Mode=="Hold" then c:_Activate(true) end
            end
        end
    end
    self:_Connect(Input.InputBegan,self._HandleInputBegan)
    self:_Connect(self.Layer:GetPropertyChangedSignal("AbsoluteSize"),function()
        self:SetSize(self.Width,self.Height)
        self.Toasts.Size=UDim2.fromOffset(math.min(286,math.max(160,self.Layer.AbsoluteSize.X-32)),0)
        self.Toasts.Position=UDim2.new(1,-self.Toasts.Size.X.Offset-16,1,-18)
    end)
    task.defer(function() if not self.Destroyed then self:SetSize(self.Width,self.Height) end end)
    self:_FXInitialize()
    if options.Branding then self:SetBranding(options.Branding)end
    if options.AllowMultiple~=true then windowRegistry[singletonKey]=self end
    return self
end

function Window:_NewPage()
    local page=setmetatable({Window=self,Sections={}},Page)
    if self.Scrollable then
        page.Frame=self:_Node("ScrollingFrame",self.PageHost,{Size=UDim2.fromScale(1,1),Visible=false,BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=3,ScrollBarImageColor3="@Border",CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollingDirection=Enum.ScrollingDirection.Y})
    else
        page.Frame=self:_Frame(self.PageHost,{Size=UDim2.fromScale(1,1),Visible=false,BackgroundTransparency=1,ClipsDescendants=true})
    end
    page.Full=self:_Frame(page.Frame,{Name="Full",Size=UDim2.new(1,-10,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1})
    page.Left=self:_Frame(page.Frame,{Name="Left",Size=UDim2.new(.5,-12,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1})
    page.Right=self:_Frame(page.Frame,{Name="Right",Size=UDim2.new(.5,-12,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1})
    self:_List(page.Full,12);self:_List(page.Left,12);self:_List(page.Right,12)
    local function layout()
        local top=page.Full.AbsoluteSize.Y
        if #page.Full:GetChildren()>1 then top+=12 end
        local narrow=self.Scrollable and page.Frame.AbsoluteSize.X<570
        page.Left.Size=UDim2.new(narrow and 1 or .5,narrow and -10 or -12,0,0)
        page.Right.Size=page.Left.Size
        page.Left.Position=UDim2.fromOffset(0,top)
        page.Right.Position=narrow and UDim2.fromOffset(0,top+page.Left.AbsoluteSize.Y+12) or UDim2.new(.5,2,0,top)
    end
    self:_Connect(page.Frame:GetPropertyChangedSignal("AbsoluteSize"),layout)
    self:_Connect(page.Full:GetPropertyChangedSignal("AbsoluteSize"),layout)
    self:_Connect(page.Left:GetPropertyChangedSignal("AbsoluteSize"),layout)
    task.defer(function() if not self.Destroyed then layout() end end)
    return page
end
function Window:_FitTabs()
    local count=#self.Tabs
    if count==0 then return end
    local width=math.max(1,(self.TabBar.Size.X.Scale*self.Width+self.TabBar.Size.X.Offset-count+1)/count)
    for _,tab in ipairs(self.Tabs)do tab.Button.Size=UDim2.fromOffset(width,30)end
end
function Window:_FitSubTabs()
    local tab=self.SelectedTab
    if not tab or #tab.SubTabs==0 then return end
    local count=#tab.SubTabs
    local available=math.max(0,self.SubBar.Size.X.Scale*self.Width+self.SubBar.Size.X.Offset-(count-1)*6)
    local width=math.max(1,available/count)
    for _,page in ipairs(tab.SubTabs)do page.Button.Size=UDim2.fromOffset(width,34)end
end
function Window:AddTab(name)
    local w=self
    local tab={Name=name,Window=w,SubTabs={},Default=w:_NewPage()}
    tab.Default.Frame.Name="Tab_"..name
    tab.Button=w:_Text(w.TabBar,name,{Size=UDim2.fromOffset(math.max(94,#name*8+26),32),BackgroundTransparency=0,BackgroundColor3="@Raised",TextXAlignment=Enum.TextXAlignment.Center},"TextButton")
    tab.Button.Name="Tab_"..name
    w:_Bevel(tab.Button)
    tab.Line=w:_Frame(tab.Button,{Position=UDim2.new(0,0,1,-2),Size=UDim2.new(1,0,0,2),BackgroundColor3="@Accent",Visible=false})
    function tab:Select()
        w:_ClosePopup()
        for _, other in ipairs(w.Tabs)do
            other.Default.Frame.Visible=false
            other.Line.Visible=other==self
            w:_Paint(other.Button,"TextColor3",other==self and "Text" or "Muted")
            for _,p in ipairs(other.SubTabs)do p.Frame.Visible=false;p.Button.Visible=other==self end
        end
        w.SelectedTab=self
        w:_FitSubTabs()
        local has=#self.SubTabs>0
        w.SubBar.Visible=has
        local pageY=has and w._subPageY or w._pageY
        w.PageHost.Position=UDim2.fromOffset(16,pageY)
        w.PageHost.Size=UDim2.new(1,-32,1,-pageY-38)
        if has then (self.SelectedSubTab or self.SubTabs[1]):Select() else self.Default.Frame.Visible=true end
    end
    function tab:AddSection(options)return self.Default:AddSection(options)end
    function tab:AddSubTab(label)
        local p=w:_NewPage()
        p.Title=label
        p.Frame.Name="Tab_"..tab.Name.."_Sub_"..label
        p.Button=w:_Text(w.SubBar,label,{Size=UDim2.fromOffset(math.max(146,#label*8+38),34),BackgroundTransparency=0,BackgroundColor3="@Raised",TextXAlignment=Enum.TextXAlignment.Center,Visible=w.SelectedTab==self,TextSize=13},"TextButton")
        p.Button.Name="Sub_"..label
        w:_Bevel(p.Button)
        p.Line=w:_Frame(p.Button,{Name="SelectedEdge",Position=UDim2.new(0,0,1,-2),Size=UDim2.new(1,0,0,2),BackgroundColor3="@Accent",Visible=false})
        p.Button.Position=UDim2.fromOffset(0,0)
        -- One shared horizontal layout; inactive tab buttons are hidden.
        if not w.SubBar:FindFirstChildOfClass("UIListLayout") then w:_List(w.SubBar,6,true) end
        function p:Select()
            w:_ClosePopup()
            tab.Default.Frame.Visible=false
            for _,other in ipairs(tab.SubTabs)do
                other.Frame.Visible=other==self
                other.Line.Visible=other==self
                w:_Paint(other.Button,"BackgroundColor3",other==self and "Hover" or "Raised")
                w:_Paint(other.Button,"TextColor3",other==self and "Accent" or "Muted")
            end
            tab.SelectedSubTab=self
        end
        w:_Connect(p.Button.Activated,function() p:Select() end)
        w:_Connect(p.Button.MouseEnter,function()if tab.SelectedSubTab~=p then w:_Paint(p.Button,"BackgroundColor3","Hover")end end)
        w:_Connect(p.Button.MouseLeave,function()w:_Paint(p.Button,"BackgroundColor3",tab.SelectedSubTab==p and "Hover" or "Raised")end)
        table.insert(self.SubTabs,p)
        if w.SelectedTab==self then self:Select() end
        return p
    end
    w:_Connect(tab.Button.Activated,function() tab:Select() end)
    table.insert(w.Tabs,tab)
    w:_FitTabs()
    if #w.Tabs==1 then tab:Select() else w:_Paint(tab.Button,"TextColor3","Muted") end
    return tab
end
function Page:AddSection(options)
    if type(options)=="string" then options={Name=options} end
    options=options or {}
    local w=self.Window
    local side=options.Side or "Left"
    assert(side=="Left" or side=="Right" or side=="Full","Section Side must be Left, Right or Full")
    local section=setmetatable({Window=w,Page=self,Controls={}},Section)
    section.Frame=w:_Frame(self[side],{Name=options.Name or "Section",Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,LayoutOrder=#self.Sections+1})
    w:_Border(section.Frame)
    w:_Node("UIPadding",section.Frame,{PaddingTop=UDim.new(0,12),PaddingBottom=UDim.new(0,12),PaddingLeft=UDim.new(0,12),PaddingRight=UDim.new(0,12)})
    w:_List(section.Frame,w.CompactControls and 5 or 8)
    local header=w:_Frame(section.Frame,{Size=UDim2.new(1,0,0,27),BackgroundColor3="@Raised",LayoutOrder=0})
    w:_Bevel(header,true)
    w:_Text(header,options.Caption or options.Name or "Section",{Size=UDim2.fromScale(1,1),TextSize=12,TextXAlignment=Enum.TextXAlignment.Center})
    table.insert(self.Sections,section)
    return section
end

function Section:_Row(name,height,description)
    local w=self.Window
    if w.CompactControls and height==26 then height=24 end
    local row=w:_Frame(self.Frame,{Name="Row_"..tostring(#self.Controls+1),Size=UDim2.new(1,0,0,height or 27),BackgroundTransparency=1,LayoutOrder=#self.Controls+1})
    local label=w:_Text(row,name or "",{Size=UDim2.new(1,0,0,24)})
    local addons=w:_Frame(row,{Name="Inline",Position=UDim2.new(1,0,0,0),AnchorPoint=Vector2.new(1,0),Size=UDim2.fromOffset(0,24),BackgroundTransparency=1})
    local layout=w:_List(addons,5,true)
    layout.VerticalAlignment=Enum.VerticalAlignment.Center
    local holder={Row=row,Label=label,Addons=addons,AddonWidth=0,AddonHeight=24,Window=w}
    if description then
        w:_Connect(row.MouseEnter,function()w.Footer.Text=description end)
        w:_Connect(row.MouseLeave,function()w.Footer.Text=w._footerText end)
    end
    holder.Layout=layout
    return holder
end
function Section:_Register(kind,options,holder,normalize,render)
    options=options or {}
    local w=self.Window
    local flag=options.Flag
    if not flag then w._nextFlag+=1;flag="control_"..w._nextFlag end
    assert(type(flag)=="string" and not w.Options[flag],"Duplicate or invalid flag: "..tostring(flag))
    local c=setmetatable({Type=kind,Flag=flag,Window=w,Section=self,Row=holder.Row,Label=holder.Label,Holder=holder,
        Callback=options.Callback,Disabled=false,Persist=options.Persist~=false,_Normalize=normalize,_Render=render},Control)
    c.Value=normalize(options.Default)
    c.Default=copy(c.Value)
    w.Options[flag]=c;w.Flags[flag]=copy(c.Value)
    table.insert(w._controls,c);table.insert(self.Controls,c)
    if render then render(c) end
    return c
end
function Control:_Call()
    if not self.Callback then return end
    local ok,err
    if self.Type=="ColorPicker" then ok,err=pcall(self.Callback,self.Value.Color,self.Value.Alpha)
    elseif self.Type=="Keybind" then ok,err=pcall(self.Callback,self.Active,self.Value.Key,self.Value.Mode)
    else ok,err=pcall(self.Callback,copy(self.Value)) end
    if not ok then warn("[Nocturne callback / "..self.Flag.."] "..tostring(err));self.Window:Notify("Callback error",self.Flag..": "..tostring(err),5) end
end
function Control:Set(value,silent)
    assert(not self.Window.Destroyed,"Window destroyed")
    local nextValue=self._Normalize(value)
    if equal(self.Value,nextValue) then return self end
    self.Value=nextValue
    self.Window.Flags[self.Flag]=copy(nextValue)
    if self._Render then self._Render(self) end
    if self.Type=="Toggle" and self.Keybinds then
        for _,bind in ipairs(self.Keybinds)do
            if bind.SyncToggle and bind.Value.Mode=="Toggle" then bind.Active=nextValue;bind._Render(bind)end
        end
    end
    if not silent then self:_Call() end
    return self
end
function Control:Get()
    if self.Type=="ColorPicker" then return self.Value.Color,self.Value.Alpha end
    if self.Type=="Keybind" then return self.Value.Key,self.Value.Mode end
    return copy(self.Value)
end
function Control:SetVisible(visible)
    self.Row.Visible=visible
    if not visible and self.Window.PopupOwner==self then self.Window:_ClosePopup() end
    return self
end
function Control:SetDisabled(disabled)
    self.Disabled=disabled==true
    self.Window:_Paint(self.Label,"TextColor3",self.Disabled and "Muted" or "Text")
    if self.Disabled and self.Window.PopupOwner==self then self.Window:_ClosePopup() end
    if self.Disabled and self.Type=="Keybind" then self:_Activate(false) end
    return self
end
function Control:SetText(text)self.Label.Text=tostring(text)return self end
function Control:Reset(silent)return self:Set(copy(self.Default),silent)end
function Section:AddToggle(options)
    options=options or {}
    local w=self.Window
    local h=self:_Row(options.Text or "Toggle",26,options.Description)
    h.Label.Position=UDim2.fromOffset(22,0);h.Label.Size=UDim2.new(1,-22,0,24)
    local box=w:_Frame(h.Row,{Position=UDim2.fromOffset(1,7),Size=UDim2.fromOffset(10,10),BackgroundColor3="@Raised"})
    w:_Shade(box)
    w:_Border(box)
    local check=w:_Text(box,"✓",{Size=UDim2.fromScale(1,1),TextSize=12,TextXAlignment=Enum.TextXAlignment.Center,TextColor3="@AccentText"})
    local button=w:_Text(h.Row,"",{Size=UDim2.fromScale(1,1)},"TextButton")
    h.Button=button
    local c=self:_Register("Toggle",options,h,function(value)
        if value==nil then return false end assert(type(value)=="boolean","Toggle needs boolean")return value
    end,function(control)
        w:_Paint(box,"BackgroundColor3",control.Value and "Accent" or "Raised");check.Visible=control.Value and w.Checkmarks
    end)
    c.Button=button
    c.ToggleBox=box
    w:_Connect(button.Activated,function()if not c.Disabled then c:Set(not c.Value)end end)
    return c
end
function Section:AddSlider(options)
    options=options or {}
    local w=self.Window
    local minimum,maximum=options.Min or 0,options.Max or 100
    local step=options.Step or 1
    assert(finite(minimum) and finite(maximum) and maximum>minimum and finite(step) and step>0,"Invalid slider range")
    local h=self:_Row(options.Text or "Slider",w.CompactControls and 42 or 52,options.Description)
    h.Label.Size=UDim2.new(1,-85,0,24)
    local valueBox=w:_Text(h.Row,"",{Position=UDim2.new(1,-80,0,0),Size=UDim2.fromOffset(80,24),TextXAlignment=Enum.TextXAlignment.Right,ClearTextOnFocus=false},"TextBox")
    local track=w:_Frame(h.Row,{Position=UDim2.fromOffset(0,33),Size=UDim2.new(1,0,0,5),BackgroundColor3="@Raised"})
    local fill=w:_Frame(track,{Size=UDim2.fromScale(0,1),BackgroundColor3="@Accent"})
    w:_Shade(fill,true);w:_Border(track,"OuterEdge")
    local knob=w:_Frame(track,{Position=UDim2.fromScale(0,0),AnchorPoint=Vector2.new(.5,.3),Size=UDim2.fromOffset(6,10),BackgroundColor3="@Text"})
    local target=w:_Frame(h.Row,{Position=UDim2.fromOffset(0,24),Size=UDim2.new(1,0,0,w.CompactControls and 18 or 24),BackgroundTransparency=1,Active=true})
    local decimals=0
    while decimals<6 and math.abs(step*10^decimals-math.floor(step*10^decimals+.5))>1e-7 do decimals+=1 end
    local normalize=function(value)
        if value==nil then value=minimum end assert(finite(value),"Slider needs finite number")
        value=math.clamp(value,minimum,maximum)
        if value==maximum then return maximum end
        return math.clamp(minimum+math.floor((value-minimum)/step+.5)*step,minimum,maximum)
    end
    local c=self:_Register("Slider",options,h,normalize,function(control)
        local ratio=(control.Value-minimum)/(maximum-minimum)
        fill.Size=UDim2.fromScale(ratio,1);knob.Position=UDim2.fromScale(ratio,0)
        valueBox.Text=string.format("%."..decimals.."f",control.Value)..(options.Suffix or "")
    end)
    c.Min,c.Max,c.Step=minimum,maximum,step
    c.Input=valueBox;c.Track=track
    w:_Drag(target,function(p)if not c.Disabled then
        c:Set(minimum+math.clamp((p.X-track.AbsolutePosition.X)/math.max(1,track.AbsoluteSize.X),0,1)*(maximum-minimum))
    end end)
    w:_Connect(valueBox.Focused,function()if c.Disabled then valueBox:ReleaseFocus()else valueBox.Text=tostring(c.Value)end end)
    w:_Connect(valueBox.FocusLost,function()
        local n=tonumber(valueBox.Text)
        if n and finite(n) and not c.Disabled then c:Set(n) end
        c._Render(c)
    end)
    return c
end
function Section:AddDropdown(options)
    options=options or {}
    local w=self.Window
    local h=self:_Row(options.Text or "Dropdown",57,options.Description)
    local button=w:_Text(h.Row,"",{Position=UDim2.fromOffset(0,28),Size=UDim2.new(1,0,0,27),BackgroundTransparency=0,BackgroundColor3="@Raised"},"TextButton")
    w:_Bevel(button)
    local selected=w:_Text(button,"",{Position=UDim2.fromOffset(9,0),Size=UDim2.new(1,-32,1,0),TextSize=12})
    w:_Text(button,"⌄",{Position=UDim2.new(1,-24,0,0),Size=UDim2.fromOffset(20,27),TextXAlignment=Enum.TextXAlignment.Center,TextColor3="@Muted"})
    local items={}
    local function setItems(values)
        assert(type(values)=="table","Items must be an array")
        local used={};items={}
        for _,value in ipairs(values)do assert(type(value)=="string" and not used[value],"Items must be unique strings");used[value]=true;items[#items+1]=value end
    end
    setItems(options.Items or {})
    local multi=options.Multi==true
    local normalize=function(value)
        if multi then
            if value==nil then return {} end assert(type(value)=="table","Multi dropdown needs array")
            local want={};for _,x in ipairs(value)do assert(table.find(items,x),"Unknown dropdown item: "..tostring(x));want[x]=true end
            local result={};for _,x in ipairs(items)do if want[x]then result[#result+1]=x end end return result
        end
        if value==nil or value=="" then return "" end
        assert(type(value)=="string" and table.find(items,value),"Unknown dropdown item: "..tostring(value))return value
    end
    local c=self:_Register("Dropdown",options,h,normalize,function(control)
        selected.Text=multi and (#control.Value>0 and table.concat(control.Value,", ") or "Select options") or (control.Value~="" and control.Value or "Select option")
        if control.RefreshPopup then control.RefreshPopup() end
    end)
    c.Multi=multi
    c.Button=button
    function c:SetItems(values,preserve)
        local old=copy(self.Value)
        setItems(values)
        -- Removed items must not leave an invalid default behind.
        if multi then
            local default={}
            for _,x in ipairs(self.Default)do if table.find(items,x)then default[#default+1]=x end end
            self.Default=default
        elseif not table.find(items,self.Default)then self.Default="" end
        local value=multi and {} or ""
        if preserve~=false then
            if multi then for _,x in ipairs(old)do if table.find(items,x)then value[#value+1]=x end end
            elseif table.find(items,old)then value=old end
        end
        self:Set(value)
        if self.RefreshPopup then self.RefreshPopup()end
        return self
    end
    w:_Connect(button.Activated,function()
        if c.Disabled then return end
        local popup=w:_Popup(button,c,math.max(210,button.AbsoluteSize.X),230)
        if not popup then c.RefreshPopup=nil return end
        local search=w:_Text(popup,"",{Name="Search",Position=UDim2.fromOffset(9,9),Size=UDim2.new(1,-18,0,27),BackgroundTransparency=0,BackgroundColor3="@Raised",PlaceholderText="Search options…",PlaceholderColor3=w.Theme.Muted,ClearTextOnFocus=false,TextSize=12,ZIndex=102},"TextBox")
        local list=w:_Node("ScrollingFrame",popup,{Name="Options",Position=UDim2.fromOffset(9,45),Size=UDim2.new(1,-18,1,-54),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=3,ScrollBarImageColor3="@Border",AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new(),ZIndex=102})
        local function refresh()
            if w.PopupOwner~=c then return end
            w:_ClearPopupItems();list:ClearAllChildren();w:_List(list,3)
            local query=search.Text:lower();local matches=0
            for _,value in ipairs(items)do if value:lower():find(query,1,true) then
                matches+=1
                local on=multi and table.find(c.Value,value)~=nil or not multi and c.Value==value
                local row=w:_Text(list,(on and "• " or "  ")..value,{Size=UDim2.new(1,-6,0,26),BackgroundTransparency=0,BackgroundColor3=on and "@Hover" or "@Panel",TextColor3=on and "@Accent" or "@Text",TextSize=12,ZIndex=103},"TextButton")
                row.Name="Option_"..value
                w:_Connect(row.Activated,function()
                    if multi then local v=copy(c.Value);local index=table.find(v,value);if index then table.remove(v,index)else v[#v+1]=value end;c:Set(v)
                    else c:Set(value);c.RefreshPopup=nil;w:_ClosePopup()end
                end,w._popupItemConnections)
            end end
            if matches==0 then w:_Text(list,"No matches",{Size=UDim2.new(1,0,0,26),TextColor3="@Muted",ZIndex=103})end
        end
        c.RefreshPopup=refresh
        w:_Connect(search:GetPropertyChangedSignal("Text"),refresh,w._popupConnections)
        refresh()
    end)
    return c
end
function Section:AddTextbox(options)
    options=options or {}
    local w=self.Window
    local h=self:_Row(options.Text or "Text",options.Multiline and 104 or 57,options.Description)
    local box=w:_Text(h.Row,"",{Position=UDim2.fromOffset(0,28),Size=UDim2.new(1,0,0,options.Multiline and 72 or 27),BackgroundTransparency=0,BackgroundColor3="@Raised",PlaceholderText=options.Placeholder or "Enter text…",PlaceholderColor3=w.Theme.Muted,ClearTextOnFocus=false,MultiLine=options.Multiline==true,TextWrapped=options.Multiline==true,TextYAlignment=options.Multiline and Enum.TextYAlignment.Top or Enum.TextYAlignment.Center,TextTruncate=Enum.TextTruncate.None,TextSize=12},"TextBox")
    w:_Node("UIPadding",box,{PaddingLeft=UDim.new(0,9),PaddingRight=UDim.new(0,9),PaddingTop=UDim.new(0,options.Multiline and 6 or 0)})
    w:_Border(box)
    w:_Shade(box,true)
    local c=self:_Register("Textbox",options,h,function(value)
        if value==nil then return "" end assert(type(value)=="string","Textbox needs string")
        assert(#value<=(options.MaxLength or 16384),"Text exceeds MaxLength")return value
    end,function(control)box.Text=control.Value end)
    c.Input=box
    w:_Connect(box.Focused,function()if c.Disabled then box:ReleaseFocus()end end)
    w:_Connect(box.FocusLost,function()
        if c.Disabled then c._Render(c)return end
        local ok=pcall(function()c:Set(box.Text)end)
        if not ok then c._Render(c);w:Notify("Invalid text","Maximum length exceeded")end
    end)
    if options.Live then w:_Connect(box:GetPropertyChangedSignal("Text"),function()
        if box:IsFocused() and not c.Disabled and #box.Text<=(options.MaxLength or 16384) then c:Set(box.Text)end
    end)end
    return c
end
function Section:AddButton(options)
    if type(options)=="string" then options={Text=options} end options=options or {}
    local w=self.Window
    local h=self:_Row("",29,options.Description)
    local button=w:_Text(h.Row,options.Text or "Button",{Size=UDim2.fromScale(1,1),BackgroundTransparency=0,BackgroundColor3="@Raised",TextXAlignment=Enum.TextXAlignment.Center},"TextButton")
    w:_Bevel(button);w:_Hover(button)
    local c={Window=w,Row=h.Row,Label=button,Disabled=false,Type="Button"}
    setmetatable(c,Control)
    function c:Press()if self.Disabled then return end;if options.Callback then local ok,err=pcall(options.Callback);if not ok then w:Notify("Callback error",tostring(err));warn(err)end end end
    w:_Connect(button.Activated,function()c:Press()end)
    table.insert(self.Controls,c)
    return c
end
function Section:AddLabel(text)
    local h=self:_Row(tostring(text or ""),26)
    local c=setmetatable({Window=self.Window,Row=h.Row,Label=h.Label,Type="Label"},Control)
    table.insert(self.Controls,c)
    return c
end
function Section:AddParagraph(title,text)
    local w=self.Window
    local h=self:_Row(title,0)
    h.Row.AutomaticSize=Enum.AutomaticSize.Y
    local body=w:_Text(h.Row,text,{Position=UDim2.fromOffset(0,27),Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,TextWrapped=true,TextTruncate=Enum.TextTruncate.None,TextColor3="@Muted",TextSize=12})
    local c=setmetatable({Window=w,Row=h.Row,Label=h.Label,Body=body,Type="Paragraph"},Control)
    function c:SetBody(value)body.Text=tostring(value)return self end
    table.insert(self.Controls,c)
    return c
end
function Section:AddSeparator(text)
    local w=self.Window
    local h=self:_Row(text or "",text and 25 or 10)
    w:_Paint(h.Label,"TextColor3","Muted");h.Label.TextSize=10
    w:_Frame(h.Row,{Position=UDim2.new(0,0,1,-1),Size=UDim2.new(1,0,0,1),BackgroundColor3="@Border"})
    local c=setmetatable({Window=w,Row=h.Row,Label=h.Label,Type="Separator"},Control)
    table.insert(self.Controls,c)return c
end

function Section:AddImagePreview(options)
    options=options or {}
    local w=self.Window
    local h=self:_Row(options.Text or "ESP preview",(options.Height or 285)+29)
    local canvas=w:_Frame(h.Row,{Name="StaticPreview",Position=UDim2.fromOffset(0,28),Size=UDim2.new(1,0,1,-28),BackgroundColor3="@Background",ClipsDescendants=true})
    w:_Border(canvas)
    local image=w:_Node("ImageLabel",canvas,{Name="Photo",Position=UDim2.fromOffset(0,18),Size=UDim2.new(1,0,1,-36),BackgroundTransparency=1,
        Image=options.Image or "",ScaleType=Enum.ScaleType.Fit,ImageColor3=Color3.new(1,1,1),
        ImageRectOffset=options.ImageRectOffset or Vector2.zero,ImageRectSize=options.ImageRectSize or Vector2.zero})
    local box=w:_Frame(canvas,{Name="ESPBounds",BackgroundTransparency=1,Visible=options.Outline~=false})
    w:_Node("UIStroke",box,{Thickness=3,Color=Color3.new(),ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
    local inner=w:_Frame(box,{Position=UDim2.fromOffset(1,1),Size=UDim2.new(1,-2,1,-2),BackgroundTransparency=1})
    local stroke=w:_Border(inner,"Accent")
    local name=w:_Text(canvas,options.Name or "Player",{TextXAlignment=Enum.TextXAlignment.Center,TextStrokeTransparency=0,TextSize=11})
    local readout=w:_Text(canvas,options.Readout or "STATIC PREVIEW",{TextXAlignment=Enum.TextXAlignment.Center,TextStrokeTransparency=0,TextSize=10})
    local c=setmetatable({Window=w,Row=h.Row,Label=h.Label,Image=image,Canvas=canvas,Bounds=box,
        OutlineStroke=stroke,NameLabel=name,DistanceLabel=readout,OutlineFrame=inner,DarkStroke=box:FindFirstChildOfClass("UIStroke"),
        Type="ImagePreview",ImageSize=options.ImageSize or Vector2.new(725,633),
        Outline=options.Outline~=false,ESPVisible=true},Control)
    local function validate(bounds)
        assert(type(bounds)=="table","Bounds need Left, Top, Width, Height")
        for _,key in ipairs({"Left","Top","Width","Height"})do assert(finite(bounds[key])and bounds[key]>=0 and bounds[key]<=1,"Invalid preview bounds")end
        assert(bounds.Left+bounds.Width<=1 and bounds.Top+bounds.Height<=1 and bounds.Width>0 and bounds.Height>0,"Preview bounds exceed image")
        return copy(bounds)
    end
    c.NormalizedBounds=validate(options.Bounds or {Left=.27,Top=.15,Width=.42,Height=.75})
    local function layout()
        local guiScale=w.Scale or 1
        local available=image.AbsoluteSize/guiScale
        local pixels=c.ImageSize
        assert(pixels.X>0 and pixels.Y>0,"ImageSize must be positive")
        local scale=math.min(available.X/pixels.X,available.Y/pixels.Y)
        local size=pixels*scale
        local offset=(available-size)*.5+(image.AbsolutePosition-canvas.AbsolutePosition)/guiScale
        local b=c.NormalizedBounds
        local x,y=offset.X+size.X*b.Left,offset.Y+size.Y*b.Top
        local width,height=size.X*b.Width,size.Y*b.Height
        box.Position=UDim2.fromOffset(x,y);box.Size=UDim2.fromOffset(width,height)
        name.Position=UDim2.fromOffset(0,math.max(1,y-18));name.Size=UDim2.new(1,0,0,16)
        readout.Position=UDim2.fromOffset(0,math.min(canvas.AbsoluteSize.Y/guiScale-16,y+height+4));readout.Size=UDim2.new(1,0,0,15)
    end
    function c:SetBounds(bounds)self.NormalizedBounds=validate(bounds);layout();return self end
    function c:SetImage(asset,size)
        assert(type(asset)=="string","Image needs an asset string")
        if size then assert(typeof(size)=="Vector2"and size.X>0 and size.Y>0,"Invalid image dimensions");self.ImageSize=size end
        image.Image=asset;layout();return self
    end
    function c:SetOutline(visible)self.Outline=visible==true;box.Visible=self.Outline and self.ESPVisible;return self end
    function c:SetESPVisible(visible)
        self.ESPVisible=visible==true;box.Visible=self.Outline and self.ESPVisible
        name.Visible=self.ESPVisible;readout.Visible=self.ESPVisible;return self
    end
    function c:SetOutlineColor(color)
        assert(typeof(color)=="Color3")
        w._themeNodes[stroke].Color=nil;stroke.Color=color
        return self
    end
    function c:SetTransparency(value)assert(finite(value)and value>=0 and value<=1);image.ImageTransparency=value;return self end
    w:_Connect(canvas:GetPropertyChangedSignal("AbsoluteSize"),layout)
    w:_Connect(image:GetPropertyChangedSignal("AbsoluteSize"),layout)
    task.defer(function()if not w.Destroyed then layout()end end)
    table.insert(self.Controls,c)
    return c
end

function Section:AddViewport(options)
    options=options or {}
    local w=self.Window
    local h=self:_Row(options.Text or "Preview",(options.Height or 230)+29)
    local backdrop=w:_Frame(h.Row,{Name="PreviewBackdrop",Position=UDim2.fromOffset(0,28),Size=UDim2.new(1,0,1,-28),BackgroundColor3=Color3.new(1,1,1)})
    w:_Node("UIGradient",backdrop,{Rotation=90,Color=ColorSequence.new(Color3.fromRGB(110,139,157),Color3.fromRGB(40,44,56))})
    local view=w:_Node("ViewportFrame",h.Row,{Position=UDim2.fromOffset(0,28),Size=UDim2.new(1,0,1,-28),BorderSizePixel=0,
        BackgroundColor3="@Background",BackgroundTransparency=1,Ambient=Color3.fromRGB(160,142,164),LightColor=Color3.fromRGB(215,215,222),LightDirection=Vector3.new(-.5,-1,-.65),Active=true})
    w:_Border(view)
    local viewportInset=w:_Frame(view,{Position=UDim2.fromOffset(2,2),Size=UDim2.new(1,-4,1,-4),BackgroundTransparency=1})
    w:_Border(viewportInset,"Highlight")
    local world=w:_Node("WorldModel",view,{})
    local camera=w:_Node("Camera",view,{FieldOfView=35})
    view.CurrentCamera=camera
    local c=setmetatable({Window=w,Row=h.Row,Label=h.Label,Viewport=view,World=world,Camera=camera,Type="Viewport",Yaw=options.Yaw or .35,Pitch=.08},Control)
    if options.Grid~=false then
        c.Stage=w:_Node("Model",world,{Name="PreviewStage"})
        w:_Node("Part",c.Stage,{Name="Floor",Size=Vector3.new(60,.08,60),CFrame=CFrame.new(0,-.08,0),Anchored=true,
            CanCollide=false,CanTouch=false,CanQuery=false,Color=Color3.fromRGB(110,117,134),Material=Enum.Material.SmoothPlastic})
        for i=-10,10 do
            for axis=1,2 do
                w:_Node("Part",c.Stage,{Name="Grid",Size=axis==1 and Vector3.new(60,.012,.025) or Vector3.new(.025,.012,60),
                    CFrame=CFrame.new(axis==1 and 0 or i*2,0,axis==1 and i*2 or 0),Anchored=true,CanCollide=false,CanTouch=false,CanQuery=false,
                    Color=Color3.fromRGB(72,80,100),Material=Enum.Material.SmoothPlastic})
            end
        end
    end
    local bounds=w:_Frame(view,{Name="ModelBounds",BackgroundTransparency=1,Visible=options.Outline==true})
    w:_Node("UIStroke",bounds,{Thickness=3,Color=Color3.new(),ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
    local inner=w:_Frame(bounds,{Position=UDim2.fromOffset(1,1),Size=UDim2.new(1,-2,1,-2),BackgroundTransparency=1})
    w:_Border(inner,"Accent")
    local modelName=w:_Text(view,options.Name or "Model",{TextXAlignment=Enum.TextXAlignment.Center,TextStrokeTransparency=0,TextSize=11})
    local readout=w:_Text(view,options.Readout or "LIVE PREVIEW",{TextXAlignment=Enum.TextXAlignment.Center,TextStrokeTransparency=0,TextSize=10})
    c.Bounds=bounds
    local function projectBounds(cf,size)
        local pixels=view.AbsoluteSize
        if pixels.X<=0 or pixels.Y<=0 then return end
        local focal=pixels.Y/(2*math.tan(math.rad(camera.FieldOfView*.5)))
        local x0,y0,x1,y1=math.huge,math.huge,-math.huge,-math.huge
        for _,x in ipairs({-1,1})do for _,y in ipairs({-1,1})do for _,z in ipairs({-1,1})do
            local point=camera.CFrame:PointToObjectSpace(cf:PointToWorldSpace(Vector3.new(size.X*x*.5,size.Y*y*.5,size.Z*z*.5)))
            if point.Z<-.001 then
                local px=pixels.X*.5+point.X/-point.Z*focal
                local py=pixels.Y*.5-point.Y/-point.Z*focal
                x0,y0,x1,y1=math.min(x0,px),math.min(y0,py),math.max(x1,px),math.max(y1,py)
            end
        end end end
        if x1<x0 then return end
        bounds.Position=UDim2.fromOffset(x0-2,y0-2);bounds.Size=UDim2.fromOffset(x1-x0+4,y1-y0+4)
        modelName.Position=UDim2.fromOffset(0,math.max(1,y0-20));modelName.Size=UDim2.new(1,0,0,17)
        readout.Position=UDim2.fromOffset(0,math.min(pixels.Y-16,y1+5));readout.Size=UDim2.new(1,0,0,15)
    end
    local function frameModel()
        if not c.Model then return end
        local cf,size=c.Model:GetBoundingBox()
        local radius=math.max(size.X,size.Y,size.Z)*.5
        local distance=math.max(.5,radius/math.tan(math.rad(camera.FieldOfView*.5)))*1.25
        local target=cf.Position
        local offset=Vector3.new(math.sin(c.Yaw)*math.cos(c.Pitch),math.sin(c.Pitch),math.cos(c.Yaw)*math.cos(c.Pitch))*distance
        camera.CFrame=CFrame.lookAt(target+offset,target)
        if c.Stage then c.Stage:PivotTo(CFrame.new(target.X,cf.Position.Y-size.Y*.5-.08,target.Z))end
        projectBounds(cf,size)
    end
    function c:SetModel(model)
        assert(typeof(model)=="Instance" and model:IsA("Model"),"Preview needs a Model")
        local cloned=model:Clone()
        assert(cloned,"Preview model is not Archivable")
        if self.Model then self.Model:Destroy()end
        self.Model=cloned;cloned.Parent=world
        for _,part in ipairs(cloned:QueryDescendants("BasePart"))do part.Anchored=true;part.CanCollide=false;part.CanTouch=false;part.CanQuery=false end
        frameModel()
        return self
    end
    function c:SetTint(color)
        assert(typeof(color)=="Color3")
        if self.Model then for _,part in ipairs(self.Model:QueryDescendants("BasePart"))do part.Color=color end end
        return self
    end
    function c:SetOutline(visible)bounds.Visible=visible==true;return self end
    if options.Interactive==true then
        local yaw,pitch
        w:_Drag(view,function(_,delta,begin)
            if begin then yaw,pitch=c.Yaw,c.Pitch end
            c.Yaw=yaw-delta.X*.012;c.Pitch=math.clamp(pitch+delta.Y*.008,-1,1)
            frameModel()
        end)
    end
    w:_Connect(view:GetPropertyChangedSignal("AbsoluteSize"),frameModel)
    if options.Model then c:SetModel(options.Model)end
    table.insert(self.Controls,c)
    return c
end

function Window:Confirm(title,message,callback)
    if self.Destroyed then return end
    self:_ClosePopup()
    if self.Modal then self.Modal:Destroy()end
    local veil=self:_Text(self.Layer,"",{Name="Modal",Size=UDim2.fromScale(1,1),BackgroundTransparency=.35,BackgroundColor3=Color3.new(),ZIndex=300},"TextButton")
    self.Modal=veil
    local card=self:_Frame(veil,{Name="Dialog",Size=UDim2.fromOffset(math.min(340,self.Layer.AbsoluteSize.X-24),172),Position=UDim2.fromScale(.5,.5),AnchorPoint=Vector2.new(.5,.5),BackgroundColor3="@Panel",ZIndex=301})
    self:_Border(card)
    self:_Shadow(card)
    self:_Text(card,title,{Position=UDim2.fromOffset(16,16),Size=UDim2.new(1,-32,0,20),TextSize=14,ZIndex=302})
    self:_Text(card,message,{Position=UDim2.fromOffset(16,45),Size=UDim2.new(1,-32,0,60),TextWrapped=true,TextTruncate=Enum.TextTruncate.None,TextColor3="@Muted",TextSize=12,ZIndex=302})
    local cancel=self:_Text(card,"Cancel",{Position=UDim2.new(0,16,1,-48),Size=UDim2.new(.5,-22,0,30),BackgroundTransparency=0,BackgroundColor3="@Raised",TextXAlignment=Enum.TextXAlignment.Center,ZIndex=302},"TextButton")
    local accept=self:_Text(card,"Confirm",{Position=UDim2.new(.5,6,1,-48),Size=UDim2.new(.5,-22,0,30),BackgroundTransparency=0,BackgroundColor3="@Accent",TextColor3="@AccentText",TextXAlignment=Enum.TextXAlignment.Center,ZIndex=302},"TextButton")
    cancel.Name="Cancel";accept.Name="Confirm"
    local cons={}
    local function close()
        for _,conn in ipairs(cons)do conn:Disconnect()end
        veil:Destroy();if self.Modal==veil then self.Modal=nil end
    end
    self:_Connect(cancel.Activated,close,cons)
    self:_Connect(accept.Activated,function()close();if callback then local ok,err=pcall(callback);if not ok then self:Notify("Callback error",tostring(err))end end end,cons)
    return veil
end

function Control:_Addon(width)
    local h=self.Holder
    assert(h,"Control does not support addons")
    h.AddonWidth+=width+(h.AddonWidth>0 and 5 or 0)
    assert(h.AddonWidth<=160,"Too many inline controls; use another row")
    h.Addons.Size=UDim2.fromOffset(h.AddonWidth,h.AddonHeight or 24)
    h.Label.Size=UDim2.new(1,-h.AddonWidth-(self.Type=="Toggle" and 32 or 8),0,h.AddonHeight or 24)
    if h.Button then h.Button.Size=UDim2.new(1,-h.AddonWidth-8,1,0)end
    return h.Addons
end
local function hex(color)
    return string.format("#%02X%02X%02X",math.floor(color.R*255+.5),math.floor(color.G*255+.5),math.floor(color.B*255+.5))
end
local function parseColor(value)
    if typeof(value)=="Color3" then return value end
    assert(type(value)=="string","Color must be Color3 or hex")
    local clean=value:gsub("^#","")
    assert(clean:match("^%x%x%x%x%x%x$"),"Hex color needs six digits")
    return Color3.fromRGB(tonumber(clean:sub(1,2),16),tonumber(clean:sub(3,4),16),tonumber(clean:sub(5,6),16))
end
function Control:AddColorPicker(options)
    options=options or {}
    local w,section=self.Window,self.Section
    local parent=self:_Addon(22)
    local swatch=w:_Text(parent,"",{Size=UDim2.fromOffset(22,11),Position=UDim2.fromOffset(0,6),BackgroundTransparency=0,BackgroundColor3=w.Theme.Accent},"TextButton")
    w:_Border(swatch)
    w:_Shade(swatch)
    local h={Row=self.Row,Label=self.Label,Window=w,Addons=parent,AddonWidth=0}
    local normalized=function(value)
        if value==nil then value=options.Color or w.Theme.Accent end
        local alpha=options.Alpha or 0
        if type(value)=="table" then alpha=value.Alpha or value.alpha or 0;value=value.Color or value.color end
        assert(finite(alpha) and alpha>=0 and alpha<=1,"Alpha must be 0..1 (transparency)")
        return {Color=parseColor(value),Alpha=alpha}
    end
    local c=section:_Register("ColorPicker",options,h,normalized,function(control)
        swatch.BackgroundColor3=control.Value.Color;swatch.BackgroundTransparency=control.Value.Alpha
        if control.RefreshPopup then control.RefreshPopup()end
    end)
    c.Swatch=swatch
    swatch.Name="Color_"..c.Flag
    c.Row=self.Row
    local baseSet=Control.Set
    function c:Set(value,alpha,silent)
        if type(alpha)=="boolean" and silent==nil then silent=alpha;alpha=nil end
        if typeof(value)=="Color3" or type(value)=="string" then value={Color=value,Alpha=alpha~=nil and alpha or self.Value.Alpha}end
        return baseSet(self,value,silent)
    end
    function c:_Serialize()return {color=hex(self.Value.Color),alpha=self.Value.Alpha}end
    w:_Connect(swatch.Activated,function()
        if c.Disabled or self.Disabled then return end
        local popup=w:_Popup(swatch,c,266,302)
        if not popup then c.RefreshPopup=nil return end
        w:_Text(popup,options.Text or "COLOR PICKER",{Position=UDim2.fromOffset(12,10),Size=UDim2.new(1,-24,0,18),TextSize=11,TextColor3="@Muted",ZIndex=102})
        local hue,saturation,value=c.Value.Color:ToHSV()
        local pad=w:_Frame(popup,{Position=UDim2.fromOffset(12,38),Size=UDim2.new(1,-24,0,145),BackgroundColor3=Color3.fromHSV(hue,1,1),Active=true,ZIndex=102})
        local white=w:_Frame(pad,{Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.new(1,1,1),ZIndex=103})
        w:_Node("UIGradient",white,{Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(1,1)})})
        local black=w:_Frame(pad,{Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.new(),ZIndex=104})
        w:_Node("UIGradient",black,{Rotation=90,Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(1,0)})})
        local dot=w:_Frame(pad,{Size=UDim2.fromOffset(7,7),AnchorPoint=Vector2.new(.5,.5),BackgroundColor3=Color3.new(1,1,1),ZIndex=105})
        w:_Border(dot)
        local hueBar=w:_Frame(popup,{Position=UDim2.fromOffset(12,195),Size=UDim2.new(1,-24,0,12),BackgroundColor3=Color3.new(1,1,1),Active=true,ZIndex=102})
        local hueColors={}
        for i=0,6 do hueColors[#hueColors+1]=ColorSequenceKeypoint.new(i/6,Color3.fromHSV(i/6,1,1))end
        w:_Node("UIGradient",hueBar,{Color=ColorSequence.new(hueColors)})
        local hueMark=w:_Frame(hueBar,{Size=UDim2.fromOffset(3,16),AnchorPoint=Vector2.new(.5,.125),BackgroundColor3=Color3.new(1,1,1),ZIndex=103})
        local alphaBar=w:_Frame(popup,{Position=UDim2.fromOffset(12,220),Size=UDim2.new(1,-24,0,12),BackgroundColor3="@Raised",Active=true,ZIndex=102})
        local alphaFill=w:_Frame(alphaBar,{Size=UDim2.fromScale(1,1),BackgroundColor3=c.Value.Color,ZIndex=103})
        w:_Node("UIGradient",alphaFill,{Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(1,1)})})
        local alphaMark=w:_Frame(alphaBar,{Size=UDim2.fromOffset(3,16),AnchorPoint=Vector2.new(.5,.125),BackgroundColor3=Color3.new(1,1,1),ZIndex=104})
        local hexBox=w:_Text(popup,hex(c.Value.Color),{Position=UDim2.fromOffset(12,245),Size=UDim2.new(.6,-15,0,27),BackgroundTransparency=0,BackgroundColor3="@Raised",ClearTextOnFocus=false,TextXAlignment=Enum.TextXAlignment.Center,ZIndex=102},"TextBox")
        local alphaBox=w:_Text(popup,"",{Position=UDim2.new(.6,0,0,245),Size=UDim2.new(.4,-12,0,27),BackgroundTransparency=0,BackgroundColor3="@Raised",ClearTextOnFocus=false,TextXAlignment=Enum.TextXAlignment.Center,ZIndex=102},"TextBox")
        hexBox.Name="Hex";alphaBox.Name="AlphaInput"
        w:_Text(popup,"HEX                 TRANSPARENCY",{Position=UDim2.fromOffset(12,277),Size=UDim2.new(1,-24,0,16),TextSize=9,TextColor3="@Muted",ZIndex=102})
        local function refresh()
            if w.PopupOwner~=c then return end
            local nextHue,nextSat,nextValue=c.Value.Color:ToHSV()
            if nextSat>0 then hue=nextHue end
            saturation,value=nextSat,nextValue
            pad.BackgroundColor3=Color3.fromHSV(hue,1,1)
            dot.Position=UDim2.fromScale(saturation,1-value);hueMark.Position=UDim2.fromScale(hue,0)
            alphaFill.BackgroundColor3=c.Value.Color;alphaMark.Position=UDim2.fromScale(c.Value.Alpha,0)
            if not hexBox:IsFocused()then hexBox.Text=hex(c.Value.Color)end
            if not alphaBox:IsFocused()then alphaBox.Text=math.floor(c.Value.Alpha*100+.5).."%"end
        end
        c.RefreshPopup=refresh
        local function drag(surface,fn)
            w:_Drag(surface,function(p)fn(p);if w.Drag then w.Drag.Popup=true end end,w._popupConnections)
        end
        drag(pad,function(p)
            saturation=math.clamp((p.X-pad.AbsolutePosition.X)/pad.AbsoluteSize.X,0,1)
            value=1-math.clamp((p.Y-pad.AbsolutePosition.Y)/pad.AbsoluteSize.Y,0,1)
            c:Set(Color3.fromHSV(hue,saturation,value))
        end)
        drag(hueBar,function(p)
            hue=math.clamp((p.X-hueBar.AbsolutePosition.X)/hueBar.AbsoluteSize.X,0,1)
            c:Set(Color3.fromHSV(hue,saturation,value))
            refresh()
        end)
        drag(alphaBar,function(p)c:Set(c.Value.Color,math.clamp((p.X-alphaBar.AbsolutePosition.X)/alphaBar.AbsoluteSize.X,0,1))end)
        w:_Connect(hexBox.FocusLost,function()
            local ok,color=pcall(parseColor,hexBox.Text)
            if ok then c:Set(color)else w:Notify("Invalid color","Use six hex digits, for example #DE81A3")end
            refresh()
        end,w._popupConnections)
        w:_Connect(alphaBox.FocusLost,function()
            local n=tonumber((alphaBox.Text:gsub("%%","")))
            if n and finite(n)then c:Set(c.Value.Color,math.clamp(n/100,0,1))end refresh()
        end,w._popupConnections)
        refresh()
    end)
    return c
end
function Section:AddColorPicker(options)
    options=options or {}
    local h=self:_Row(options.Text or "Color",26,options.Description)
    local shell=setmetatable({Window=self.Window,Section=self,Holder=h,Row=h.Row,Label=h.Label,Type="ColorRow"},Control)
    table.insert(self.Controls,shell)
    return shell:AddColorPicker(options)
end
function Control:_Activate(active,silent)
    if self.Active==active then return end
    self.Active=active
    if self.SyncToggle then self.ParentControl:Set(active,silent)end
    if self._Render then self._Render(self)end
    if not silent then self:_Call()end
end
function Control:_CancelCapture()
    self.Window.Capture=nil
    self.Window.Footer.Text=self.Window._footerText
    if self._Render then self._Render(self)end
end
function Control:AddKeybind(options)
    options=options or {}
    local w,section=self.Window,self.Section
    local parent=self:_Addon(104)
    local holder=self.Holder
    holder.AddonHeight=32
    parent.Size=UDim2.fromOffset(holder.AddonWidth,32)
    holder.Label.Size=UDim2.new(1,-holder.AddonWidth-(self.Type=="Toggle" and 32 or 8),0,32)
    if self.Row.Size.Y.Offset<32 then self.Row.Size=UDim2.new(1,0,0,32)end
    if self.ToggleBox then self.ToggleBox.Position=UDim2.fromOffset(1,11)end
    local cap=w:_Frame(parent,{Name="Keycap",Size=UDim2.fromOffset(104,28),BackgroundColor3="@Raised",ClipsDescendants=true})
    w:_Bevel(cap)
    local button=w:_Text(cap,"",{Size=UDim2.new(1,-22,1,0),TextXAlignment=Enum.TextXAlignment.Center,TextSize=13},"TextButton")
    local menu=w:_Text(cap,"v",{Position=UDim2.new(1,-22,0,0),Size=UDim2.fromOffset(22,28),TextXAlignment=Enum.TextXAlignment.Center,TextSize=11,TextColor3="@Muted"},"TextButton")
    w:_Frame(cap,{Position=UDim2.new(1,-23,0,4),Size=UDim2.new(0,1,1,-8),BackgroundColor3="@Border"})
    local light=w:_Frame(cap,{Position=UDim2.new(0,1,1,-2),Size=UDim2.new(1,-2,0,1),BackgroundColor3="@Accent",Visible=false})
    local names={LeftControl="L Ctrl",RightControl="R Ctrl",LeftShift="L Shift",RightShift="R Shift",
        LeftAlt="L Alt",RightAlt="R Alt",MB1="Mouse 1",MB2="Mouse 2",PageUp="PgUp",PageDown="PgDn",None="Unbound"}
    local function friendly(key)return names[key]or key end
    local normalize=function(value)
        if value==nil then value={Key=options.Key or "None",Mode=options.Mode or "Toggle"}end
        if typeof(value)=="EnumItem" then value=value.Name end
        if type(value)=="string" then value={Key=value,Mode=options.Mode or "Toggle"}end
        assert(type(value)=="table" and validKey(value.Key),"Invalid keybind key")
        assert(value.Mode=="Toggle" or value.Mode=="Hold" or value.Mode=="Always","Invalid keybind mode")
        return {Key=value.Key,Mode=value.Mode}
    end
    local h={Row=self.Row,Label=self.Label,Window=w,Addons=parent,AddonWidth=0}
    local c=section:_Register("Keybind",options,h,normalize,function(control)
        local capturing=w.Capture==control
        button.Text=capturing and "Press key…" or friendly(control.Value.Key)
        button.TextSize=capturing and 11 or 13
        w:_Paint(button,"TextColor3",(capturing or control.Active) and "Accent" or "Text")
        light.Visible=capturing or control.Active==true
    end)
    c.ParentControl=self
    c.SyncToggle=options.SyncToggle==true and self.Type=="Toggle"
    c.Active=c.Value.Mode=="Always" or c.SyncToggle and c.Value.Mode=="Toggle" and self.Value
    self.Keybinds=self.Keybinds or {};table.insert(self.Keybinds,c)
    c.Button=button;c.MenuButton=menu;c.Keycap=cap
    cap.Name="Keycap_"..c.Flag;button.Name="Key_"..c.Flag;menu.Name="Modes"
    c._Render(c)
    local baseSet=Control.Set
    function c:Set(key,mode,silent)
        if type(mode)=="boolean" and silent==nil then silent=mode;mode=nil end
        if typeof(key)=="EnumItem" then key=key.Name end
        if type(key)=="string"then key={Key=key,Mode=mode or self.Value.Mode}end
        local nextValue=self._Normalize(key)
        if equal(nextValue,self.Value)then return self end
        baseSet(self,nextValue,true)
        self.Active=nextValue.Mode=="Always" or self.SyncToggle and nextValue.Mode=="Toggle" and self.ParentControl.Value
        self._Render(self)
        if not silent then self:_Call()end
        return self
    end
    function c:Capture()
        if self.Disabled or self.ParentControl.Disabled then return self end
        if w.Capture==self then self:_CancelCapture();return self end
        w:_ClosePopup()
        if w.Capture then w.Capture:_CancelCapture()end
        w.Capture=self
        w.Footer.Text="Press a key or mouse button · Escape cancels · Backspace clears"
        self._Render(self)
        return self
    end
    function c:Clear()return self:Set("None",self.Value.Mode)end
    function c:OpenModes()
        if self.Disabled or self.ParentControl.Disabled then return self end
        if w.Capture then w.Capture:_CancelCapture()end
        local popup=w:_Popup(cap,self,258,234)
        if not popup then return self end
        w:_Text(popup,"KEYBIND",{Position=UDim2.fromOffset(12,10),Size=UDim2.new(1,-100,0,20),TextSize=11,TextColor3="@Muted",ZIndex=102})
        w:_Text(popup,friendly(self.Value.Key),{Position=UDim2.new(1,-104,0,10),Size=UDim2.fromOffset(92,20),TextXAlignment=Enum.TextXAlignment.Right,TextSize=13,TextColor3="@Accent",ZIndex=102})
        w:_Frame(popup,{Position=UDim2.fromOffset(12,37),Size=UDim2.new(1,-24,0,1),BackgroundColor3="@Border",ZIndex=102})
        local descriptions={Toggle="Press to switch on or off",Hold="Active while the key is held",Always="Active without a shortcut"}
        for i,mode in ipairs({"Toggle","Hold","Always"})do
            local selected=self.Value.Mode==mode
            local option=w:_Text(popup,"",{Name="Mode_"..mode,Position=UDim2.fromOffset(9,45+(i-1)*43),Size=UDim2.new(1,-18,0,39),BackgroundTransparency=0,
                BackgroundColor3=selected and "@Hover" or "@Raised",ZIndex=102},"TextButton")
            w:_Text(option,mode,{Position=UDim2.fromOffset(9,3),Size=UDim2.new(1,-32,0,17),TextSize=13,TextColor3=selected and "@Accent" or "@Text",ZIndex=103})
            w:_Text(option,descriptions[mode],{Position=UDim2.fromOffset(9,21),Size=UDim2.new(1,-18,0,13),TextSize=9,TextColor3="@Muted",ZIndex=103})
            if selected then w:_Frame(option,{Position=UDim2.new(1,-16,0,9),Size=UDim2.fromOffset(5,5),BackgroundColor3="@Accent",ZIndex=103})end
            w:_Connect(option.Activated,function()self:Set(self.Value.Key,mode);w:_ClosePopup()end,w._popupConnections)
        end
        local clear=w:_Text(popup,"Clear shortcut",{Name="ClearShortcut",Position=UDim2.fromOffset(9,187),Size=UDim2.new(1,-18,0,33),
            BackgroundTransparency=0,BackgroundColor3="@Raised",TextColor3="@Muted",TextXAlignment=Enum.TextXAlignment.Center,TextSize=12,ZIndex=102},"TextButton")
        w:_Connect(clear.Activated,function()self:Clear();w:_ClosePopup()end,w._popupConnections)
        return self
    end
    w:_Connect(button.Activated,function()c:Capture()end)
    w:_Connect(menu.Activated,function()c:OpenModes()end)
    w:_Connect(button.MouseButton2Click,function()c:OpenModes()end)
    w:_Connect(cap.MouseEnter,function()
        if not w.Capture then w.Footer.Text=c.Value.Mode.." · click key to rebind · arrow for options"end
    end)
    w:_Connect(cap.MouseLeave,function()if not w.Capture then w.Footer.Text=w._footerText end end)
    return c
end

function Section:AddKeybind(options)
    options=options or {}
    local h=self:_Row(options.Text or "Keybind",26,options.Description)
    local shell=setmetatable({Window=self.Window,Section=self,Holder=h,Row=h.Row,Label=h.Label,Type="KeybindRow"},Control)
    table.insert(self.Controls,shell)
    return shell:AddKeybind(options)
end
function Window:ExportConfig()
    local values={}
    for flag,c in pairs(self.Options)do if c.Persist then values[flag]=c._Serialize and c:_Serialize() or copy(c.Value)end end
    return Http:JSONEncode({version=1,values=values,effects=copy(self.Effects)})
end
function Window:LoadConfig(json,fireCallbacks)
    local ok,err=pcall(function()
        assert(not self.Destroyed,"Window destroyed")
        local data=type(json)=="string" and Http:JSONDecode(json) or json
        assert(type(data)=="table" and data.version==1 and type(data.values)=="table","Invalid Nocturne configuration")
        local effects=data.effects and normalizedEffects(data.effects,self.Effects)
        local validated={}
        for _,c in ipairs(self._controls)do local value=data.values[c.Flag];if c.Persist and value~=nil then validated[#validated+1]={Control=c,Value=c._Normalize(value)}end end
        -- Validate every known value before changing any control.
        self.LoadingConfig=true
        if effects then self:SetEffects(effects)end
        for _,entry in ipairs(validated)do entry.Control:Set(entry.Value,true)end
        if fireCallbacks then for _,entry in ipairs(validated)do entry.Control:_Call()end end
    end)
    self.LoadingConfig=false
    return ok,not ok and tostring(err)or nil
end
function Window:ResetConfig(fireCallbacks)
    self.LoadingConfig=true
    for _,c in ipairs(self._controls)do c:Reset(true)end
    if fireCallbacks then for _,c in ipairs(self._controls)do c:_Call()end end
    self.LoadingConfig=false
    return self
end
function Window:SaveConfig(name)
    if not self.Storage then return false,"No storage adapter configured"end
    local ok,err=pcall(self.Storage.Write,name,self:ExportConfig())
    return ok,not ok and tostring(err)or nil
end
function Window:ReadConfig(name,fireCallbacks)
    if not self.Storage then return false,"No storage adapter configured"end
    local ok,value=pcall(self.Storage.Read,name)
    if not ok then return false,tostring(value)end
    return self:LoadConfig(value,fireCallbacks)
end
function Library.ExecutorStorage(directory)
    assert(type(writefile)=="function" and type(readfile)=="function","Filesystem unavailable; inject your own Storage adapter")
    directory=directory or "Nocturne"
    assert(directory:match("^[%w_%-/]+$") and not directory:find("..",1,true),"Invalid directory")
    if type(makefolder)=="function" and type(isfolder)=="function" and not isfolder(directory)then makefolder(directory)end
    local function path(name)
        assert(type(name)=="string" and name:match("^[%w_%-]+$"),"Profile names accept letters, digits, _ and -")
        return directory.."/"..name..".json"
    end
    return {Write=function(name,json)writefile(path(name),json)end,Read=function(name)return readfile(path(name))end}
end
return Library
