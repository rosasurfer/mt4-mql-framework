<chart>
symbol=GBPUSD
period=60
digits=5

leftpos=9229
scale=2
graph=1
fore=0
grid=0
volume=0
ohlc=0
askline=0
days=0
descriptions=1
scroll=0
shift=1
shift_size=50

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
height=300

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
name=.attic/Gammarat Channel
flags=339
window_num=0
<inputs>
MA.Periods=111
MA.AppliedPrice=Weighted
Bands.Deviations=2.5
Bands.Color=16436871
Bands.LineWidth=3
RepaintingMode=1
MarkReversals=0
AlertsOn=1
</inputs>
</expert>

color_0=16711935
style_0=2
color_1=16436871
color_2=16436871
color_3=16711680
color_4=16711680
color_5=16711935
weight_5=2

show_data=1
</indicator>

</window>
</chart>
