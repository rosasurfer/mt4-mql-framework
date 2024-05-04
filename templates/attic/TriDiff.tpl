<chart>
symbol=USDCHF
period=60
leftpos=13564
digits=5
scale=4
graph=1
fore=0
grid=0
volume=0
scroll=0
shift=1
ohlc=0
askline=0
days=0
descriptions=1
shift_size=50
fixed_pos=620
window_left=0
window_top=0
window_right=1304
window_bottom=1032
window_type=3
background_color=16316664
foreground_color=0
barup_color=30720
bardown_color=210
bullcandle_color=30720
bearcandle_color=210
chartline_color=8421504
volumes_color=30720
grid_color=14474460
askline_color=9639167
stops_color=17919

<window>
height=100

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
period_flags=0
show_data=0
</indicator>

<indicator>
name=Custom Indicator
<expert>
name=ChartInfos
flags=347
window_num=0
</expert>
period_flags=0
show_data=0
</indicator>

<indicator>
name=Custom Indicator
<expert>
name=SuperBars
flags=339
window_num=0
</expert>
period_flags=0
show_data=0
</indicator>

<indicator>
name=Custom Indicator
<expert>
name=Moving Average
flags=339
window_num=0
<inputs>
MA.Periods=9
MA.Method=ALMA
Color.UpTrend=16776960
Color.DownTrend=16711935
</inputs>
</expert>
period_flags=0
show_data=1
</indicator>

<indicator>
name=Custom Indicator
<expert>
name=Moving Average
flags=339
window_num=0
<inputs>
MA.Periods=22
MA.Method=TMA
Color.UpTrend=16711680
Color.DownTrend=255
Draw.Width=1
</inputs>
</expert>
period_flags=0
show_data=1
</indicator>
</window>

<window>
height=18
fixed_height=0
<indicator>
name=Custom Indicator
<expert>
name=MACD
flags=339
window_num=1
<inputs>
Fast.MA.Periods=9
Fast.MA.Method=ALMA
Slow.MA.Periods=22
Slow.MA.Method=TMA
Color.MainLine=-16777216
Color.Histogram.Upper=3329330
Color.Histogram.Lower=255
</inputs>
</expert>
period_flags=0
show_data=1
</indicator>
</window>

<window>
height=18
fixed_height=0
<indicator>
name=Relative Strength Index
period=10
apply=0
color=16748574
style=0
weight=1
min=10
max=90
levels_color=12632256
levels_style=2
levels_weight=1
level_0=30
level_1=70
period_flags=0
show_data=1
</indicator>
</window>

</chart>
