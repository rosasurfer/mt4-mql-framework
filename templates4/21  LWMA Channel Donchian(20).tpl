<!--
EMA(144,36,Median)
Donchian Channel(20) 
LWMA(55) Channel + Bars
-->

<chart>
symbol=GBPUSD
period=60
digits=5

leftpos=9229
scale=4
graph=1
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
askline_color=13158600
stops_color=17919

<window>
height=4640
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
NumberOfInsideBars=3
</inputs>
</expert>
period_flags=3
show_data=0
</indicator>

<indicator>
name=Custom Indicator
<expert>
name=Chart Legend
flags=339
window_num=0
<inputs>
Text=LWMA Channel Bars
</inputs>
</expert>
show_data=0
</indicator>

<indicator>
name=Custom Indicator
<expert>
name=Moving Average
flags=339
window_num=0
<inputs>
MA.Method=SMA | LWMA | EMA* | SMMA | ALMA
MA.Periods=144
MA.Periods.Step=0
MA.AppliedPrice=Open | High | Low | Close | Median | Typical | Weighted*
Trend.Method=Slope | Channel*
Draw.Type=Line* | Dot
Draw.Width=4
Background.Width=2
Background.Color=11119017
UpTrend.Color=16748574
DownTrend.Color=65535
ShowChartLegend=0
SaveCPU=5
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
MA.Method=SMA | LWMA | EMA* | SMMA | ALMA
MA.Periods=36
MA.Periods.Step=0
MA.AppliedPrice=Open | High | Low | Close | Median | Typical | Weighted*
Trend.Method=Slope | Channel*
Draw.Type=Line* | Dot
Draw.Width=3
Background.Width=2
Background.Color=11119017
UpTrend.Color=16748574
DownTrend.Color=65535
ShowChartLegend=0
SaveCPU=5
</inputs>
</expert>
show_data=1
</indicator>

<indicator>
name=Custom Indicator
<expert>
name=Trend Bars
flags=339
window_num=0
<inputs>
MaChannel.Method=SMA | LWMA* | EMA | SMMA | ALMA
MaChannel.Periods=55
MaChannel.Width.Pct=120
Color.UpTrend=16711680
Color.DownTrend=255
Color.NoTrend=11119017
BarWidth=2
AutoConfiguration=0
</inputs>
</expert>
show_data=0
</indicator>

<indicator>
name=Custom Indicator
<expert>
name=MA Channel
flags=339
window_num=0
<inputs>
MA1.Method=LWMA
MA1.Periods=55
MA1.ChannelWidth.Pct=120
ShowChartLegend=0
</inputs>
</expert>
show_data=1
</indicator>

<indicator>
name=Custom Indicator
<expert>
name=Donchian Channel
flags=339
window_num=0
<inputs>
Periods=20
ShowChannel=1
Channel.UpperColor=16711680
Channel.LowerColor=255
ShowReversals=on* | off | +N | -N
Reversal.Symbol=dot | thin-ring | ring | thick-ring*
Reversal.Width=2
Reversal.Color=0
Signal.onReversal=1
Signal.onReversal.Types=sound* | alert* | mail | telegram
Sound.onChannelWidening=0
</inputs>
</expert>
style_0=2
style_1=2
style_2=2
show_data=1
</indicator>
</window>
</chart>
