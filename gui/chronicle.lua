-- GUI viewer for chronicle entries
--@module=true

local chronicle = reqscript('chronicle')
local gui = require('gui')
local widgets = require('gui.widgets')

ChronicleView = defclass(ChronicleView, gui.FramedScreen)
ChronicleView.ATTRS{
    frame_title='Chronicle',
    frame_style=gui.GREY_LINE_FRAME,
    frame_width=60,
    frame_height=20,
    frame_inset=1,
}

function ChronicleView:init()
    self.entries = chronicle.get_full_entries()
    self.start = 1
    self.start_min = 1
    self.start_max = math.max(1, #self.entries - self.frame_height + 1)
end

function ChronicleView:onRenderBody(dc)
    for i=self.start, math.min(#self.entries, self.start + self.frame_height - 1) do
        dc:string(self.entries[i]):newline()
    end
    dc:pen(COLOR_LIGHTCYAN)
    if self.start > self.start_min then
        dc:seek(self.frame_width-1,0):char(24)
    end
    if self.start < self.start_max then
        dc:seek(self.frame_width-1,self.frame_height-1):char(25)
    end
end

function ChronicleView:onInput(keys)
    if keys.LEAVESCREEN or keys.SELECT then
        self:dismiss()
        view = nil
    elseif keys.STANDARDSCROLL_UP then
        self.start = math.max(self.start_min, self.start - 1)
    elseif keys.STANDARDSCROLL_DOWN then
        self.start = math.min(self.start_max, self.start + 1)
    elseif keys.STANDARDSCROLL_PAGEUP then
        self.start = math.max(self.start_min, self.start - self.frame_height)
    elseif keys.STANDARDSCROLL_PAGEDOWN then
        self.start = math.min(self.start_max, self.start + self.frame_height)
    elseif keys.STANDARDSCROLL_TOP then
        self.start = self.start_min
    elseif keys.STANDARDSCROLL_BOTTOM then
        self.start = self.start_max
    else
        ChronicleView.super.onInput(self, keys)
    end
end

function show()
    view = view and view:raise() or ChronicleView{}
    view:show()
end

if not dfhack_flags.module then
    show()
end
