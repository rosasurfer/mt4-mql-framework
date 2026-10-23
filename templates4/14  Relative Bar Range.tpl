<!--
XARD EMA(144,36,9,Median) Trend
Donchian Channel(50)
===============================
Current Range / ATR(20)
-->

<chart>
symbol=GBPUSD
period=1
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
height=4400
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
name=MQL5/XU v4-XARDFX
flags=339
window_num=0
<inputs>
Indicator=XU v4-XARDFX
STR00=--- [00] Candle Settings ---
showCandles=true
cWick=1
CandleUp=16711680
CandleWt=11119017
CandleDn=255
STR01=--- [01] T3MA Trend Settings ---
showT3MA=false
STR02=--- [02] T2MA Trend Settings ---
showT2MA=false
T2MAper=144
T2MAmode=1
T2MAshift=-1
T2MAtype=4
T2MAwidth=5
T2MAbgclr=-1
T2MAupclr=16748574
T2MAdnclr=55295
STR03=--- [03] T1MA Trend Settings ---
showT1MA=false
T1MAper=36
T1MAmode=1
T1MAshift=-1
T1MAtype=4
T1MAwidth=4
T1MAbgclr=-1
T1MAupclr=16748574
T1MAdnclr=55295
STR04=--- [04] S1MA Signal Settings ---
showS1MA=false
S1MAper=9
S1MAmode=1
S1MAshift=-1
S1MAtype=4
S1MAwidth=3
S1MAbgclr=-1
S1MAupclr=16748574
STR05=--- [05] BOXtxt Settings ---
showBOXtxt=false
STR06===== [06] Alert Settings ====
inpAlertsOn=false
inpAlertsMessage=false
inpAlertsSound=false
inpAlertsPushNotif=false
inpAlertsEmail=false
</inputs>
</expert>
shift_0=0
draw_0=2
color_0=16711680
style_0=0
weight_0=1
shift_1=0
draw_1=12
color_1=0
style_1=0
weight_1=0
shift_2=0
draw_2=2
color_2=11119017
style_2=0
weight_2=1
shift_3=0
draw_3=2
color_3=255
style_3=0
weight_3=1
shift_4=0
draw_4=2
color_4=16711680
style_4=0
weight_4=2
shift_5=0
draw_5=12
color_5=0
style_5=0
weight_5=0
shift_6=0
draw_6=2
color_6=11119017
style_6=0
weight_6=2
shift_7=0
draw_7=2
color_7=255
style_7=0
weight_7=2
shift_8=0
draw_8=12
color_8=1973790
style_8=0
weight_8=16
shift_9=0
draw_9=12
color_9=14772545
style_9=0
weight_9=12
shift_10=0
draw_10=12
color_10=14772545
style_10=0
weight_10=12
shift_11=0
draw_11=12
color_11=55295
style_11=0
weight_11=12
shift_12=0
draw_12=12
color_12=55295
style_12=0
weight_12=12
shift_13=0
draw_13=12
color_13=0
style_13=0
weight_13=0
shift_14=0
draw_14=12
color_14=0
style_14=0
weight_14=0
shift_15=0
draw_15=0
color_15=4294967295
style_15=0
weight_15=9
shift_16=0
draw_16=0
color_16=16748574
style_16=0
weight_16=5
shift_17=0
draw_17=0
color_17=16748574
style_17=0
weight_17=5
shift_18=0
draw_18=0
color_18=55295
style_18=0
weight_18=5
shift_19=0
draw_19=0
color_19=55295
style_19=0
weight_19=5
shift_20=0
draw_20=12
color_20=0
style_20=0
weight_20=0
shift_21=0
draw_21=12
color_21=0
style_21=0
weight_21=0
shift_22=0
draw_22=0
color_22=4294967295
style_22=0
weight_22=8
shift_23=0
draw_23=0
color_23=16748574
style_23=0
weight_23=4
shift_24=0
draw_24=0
color_24=16748574
style_24=0
weight_24=4
shift_25=0
draw_25=0
color_25=55295
style_25=0
weight_25=4
shift_26=0
draw_26=0
color_26=55295
style_26=0
weight_26=4
shift_27=0
draw_27=12
color_27=0
style_27=0
weight_27=0
shift_28=0
draw_28=12
color_28=0
style_28=0
weight_28=0
shift_29=0
draw_29=0
color_29=4294967295
style_29=0
weight_29=7
shift_30=0
draw_30=0
color_30=16748574
style_30=0
weight_30=3
shift_31=0
draw_31=0
color_31=16748574
style_31=0
weight_31=3
shift_32=0
draw_32=0
color_32=55295
style_32=0
weight_32=3
shift_33=0
draw_33=0
color_33=55295
style_33=0
weight_33=3
shift_34=0
draw_34=12
color_34=0
style_34=0
weight_34=0
shift_35=0
draw_35=12
color_35=0
style_35=0
weight_35=0
shift_36=0
draw_36=12
color_36=0
style_36=0
weight_36=0
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
MA.Method=SMA | LWMA | EMA* | SMMA | ALMA
MA.Periods=144
MA.Periods.Step=0
MA.AppliedPrice=Open | High | Low | Close | Median | Typical | Weighted*
Draw.Type=Line* | Dot
Draw.Width=4
UpTrend.Color=16748574
DownTrend.Color=65535
Background.Color=11119017
Background.Width=2
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
Draw.Type=Line* | Dot
Draw.Width=3
UpTrend.Color=16748574
DownTrend.Color=65535
Background.Color=11119017
Background.Width=2
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
MA.Periods=9
MA.Periods.Step=0
MA.AppliedPrice=Open | High | Low | Close | Median | Typical | Weighted*
Draw.Type=Line* | Dot
Draw.Width=0
UpTrend.Color=16711680
DownTrend.Color=16711680
Background.Width=0
ShowChartLegend=0
SaveCPU=5
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
Periods=50
ShowChannel=1
Channel.UpperColor=16711680
Channel.LowerColor=255
ShowReversals=on* | off | +N | -N
Reversal.Symbol=dot | thin-ring | ring | thick-ring*
Reversal.Width=3
Signal.onReversal=1
Signal.onReversal.Types=sound* | alert* | mail | telegram
Sound.onChannelWidening=1
</inputs>
</expert>
style_0=2
style_1=2
style_2=2
show_data=1
</indicator>
</window>

<window>
height=600
fixed_height=0

<indicator>
name=Custom Indicator
<expert>
name=Average True Range
flags=339
window_num=2
<inputs>
MA.Method=SMA* | LWMA | EMA | SMMA
MA.Periods=1
TrueRange=1
Line.Width=1
Line.Color=16711680
</inputs>
</expert>
min=3.0
period_flags=0
show_data=1
</indicator>

<indicator>
name=Moving Average
period=30
method=0
apply=7
color=-1
period_flags=0
show_data=1
</indicator>

<indicator>
name=Moving Average
period=7
method=3
apply=7
color=16711680
weight=2
period_flags=0
show_data=1
</indicator>
</window>
</chart>
