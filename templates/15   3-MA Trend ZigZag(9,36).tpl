<chart>
symbol=GBPUSD
period=60
digits=5

leftpos=9229
scale=4
graph=0
fore=0
grid=0
volume=0
ohlc=0
askline=0
days=0
descriptions=1
scroll=1
shift=1
shift_size=10

fixed_pos=620
window_left=0
window_top=0
window_right=1292
window_bottom=812
window_type=3

background_color=16316664
foreground_color=0
barup_color=30720
bardown_color=210
bullcandle_color=30720
bearcandle_color=210
chartline_color=11119017
volumes_color=30720
grid_color=14474460
askline_color=9639167
stops_color=17919

<window>
height=800
fixed_height=0

<indicator>
name=main
</indicator>

<indicator>
name=Custom Indicator
<expert>
name=Grid
flags=347
window_num=0
</expert>
show_data=0
</indicator>

<indicator>
name=Custom Indicator
<expert>
name=ChartInfos
flags=347
window_num=0
</expert>
show_data=0
</indicator>

<indicator>
name=Custom Indicator
<expert>
name=SuperBars
flags=339
window_num=0
</expert>
show_data=0
</indicator>

<indicator>
name=Custom Indicator
<expert>
name=Inside Bars
flags=339
window_num=0
<inputs>
Timeframe=H1
NumberOfInsideBars=2
</inputs>
</expert>
period_flags=3
show_data=0
</indicator>

<indicator>
name=Custom Indicator
<expert>
name=Moving Average
flags=339
window_num=0
<inputs>
MA.Periods=144
MA.Method=SMA | LWMA | EMA* | SMMA | ALMA
MA.AppliedPrice=Open | High | Low | Close* | Median | Typical | Weighted
UpTrend.Color=16760576
DownTrend.Color=55295
Draw.Type=Line* | Dot
Draw.Width=4
Background.Color=6908265
Background.Width=2
ShowChartLegend=0
Signal.onTrendChange=0
AutoConfiguration=0
</inputs>
</expert>
show_data=1
</indicator>

<indicator>
name=Custom Indicator
<expert>
name=Moving Average
flags=339
window_num=0
<inputs>
MA.Periods=36
MA.Method=SMA | LWMA | EMA* | SMMA | ALMA
MA.AppliedPrice=Open | High | Low | Close* | Median | Typical | Weighted
UpTrend.Color=16760576
DownTrend.Color=55295
Draw.Type=Line* | Dot
Draw.Width=4
Background.Color=6908265
Background.Width=2
ShowChartLegend=0
Signal.onTrendChange=0
AutoConfiguration=0
</inputs>
</expert>
show_data=1
</indicator>

<indicator>
name=Custom Indicator
<expert>
name=Moving Average
flags=339
window_num=0
<inputs>
MA.Periods=9
MA.Method=SMA | LWMA | EMA* | SMMA | ALMA
MA.AppliedPrice=Open | High | Low | Close* | Median | Typical | Weighted
UpTrend.Color=16760576
DownTrend.Color=55295
Draw.Type=Line* | Dot
Draw.Width=3
Background.Color=6908265
Background.Width=2
ShowChartLegend=0
Signal.onTrendChange=0
AutoConfiguration=0
</inputs>
</expert>
show_data=1
</indicator>

<indicator>
name=Custom Indicator
<expert>
name=ZigZag
flags=339
window_num=0
<inputs>
ZigZag.Periods=36
ZigZag.Type=Line | Semaphores*
ZigZag.Width=3
ZigZag.Color=9639167
Donchian.ShowChannel=1
Donchian.ShowCrossings=off | first* | all
Show123Projections=0
ShowChartLegend=1
Signal.onReversal=0
Signal.onBreakout=1
Signal.onBreakout.123Only=1
Signal.onBreakout.Types=sound
</inputs>
</expert>
style_2=2
style_3=2
color_6=4294967295
color_7=4294967295
show_data=1
</indicator>

<indicator>
name=Custom Indicator
<expert>
name=ZigZag
flags=339
window_num=0
<inputs>
ZigZag.Periods=9
ZigZag.Type=Line* | Semaphores
ZigZag.Width=2
ZigZag.Color=16711680
Donchian.ShowChannel=0
Donchian.ShowCrossings=off | first* | all
Donchian.Crossings.Wingdings=108
Show123Projections=1
ShowChartLegend=0
Signal.onReversal=0
Signal.onBreakout=1
Signal.onBreakout.123Only=1
Signal.onBreakout.Types=sound
</inputs>
</expert>
style_2=2
style_3=2
color_6=4294967295
color_7=4294967295
show_data=1
</indicator>

</window>
</chart>
