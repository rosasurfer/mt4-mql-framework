<!--
"XU v4-XARDFX" MA parameters produce a display of shift=0.
-->

<chart>
symbol=GBPUSD
period=30
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

background_color=1381137
foreground_color=11119017
barup_color=4838975
bardown_color=8421631
bullcandle_color=5737262
bearcandle_color=4800490
chartline_color=-1
volumes_color=3329330
grid_color=4671303
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
<inputs>
Color.RegularGrid=4671303
Color.SuperGrid=13882323
AutoConfiguration=0
</inputs>
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
name=.Xard/2021.05.04/indicators/XU v4-XARDFX
flags=339
window_num=0
<inputs>
Indicator=XU v4-XARDFX
STR00=<<<==== [00] Candle Settings ====>>>
showCandles=true
cWick=1
CandleUp=4838975
CandleWt=6908265
CandleDn=4800490
STR01=<<<==== [01] T3MA Trend Settings ====>>>
showT3MA=false
STR02=<<<==== [02] T2MA Trend Settings ====>>>
showT2MA=true
T2MAper=144
T2MAmode=1
T2MAshift=-1
T2MAtype=0
T2MAwidth=5
T2MAbgclr=1973790
T2MAupclr=14772545
T2MAdnclr=55295
STR03=<<<==== [03] T1MA Trend Settings ====>>>
showT1MA=true
T1MAper=36
T1MAmode=1
T1MAshift=-1
T1MAtype=0
T1MAwidth=4
T1MAbgclr=1973790
T1MAupclr=14772545
T1MAdnclr=55295
STR04=<<<==== [04] S1MA Signal Settings ====>>>
showS1MA=true
S1MAper=9
S1MAmode=1
S1MAshift=-1
S1MAtype=0
S1MAwidth=3
S1MAbgclr=1973790
S1MAupclr=14772545
STR05=<<<==== [05] BOXtxt Settings ====>>>
showBOXtxt=false
STR06=<<<==== [06] Alert Settings ====>>>
inpAlertsOn=false
</inputs>
</expert>
shift_0=0
draw_0=2
color_0=4838975
style_0=0
weight_0=1
shift_1=0
draw_1=12
color_1=0
style_1=0
weight_1=0
shift_2=0
draw_2=2
color_2=6908265
style_2=0
weight_2=1
shift_3=0
draw_3=2
color_3=4800490
style_3=0
weight_3=1
shift_4=0
draw_4=2
color_4=4838975
style_4=0
weight_4=3
shift_5=0
draw_5=12
color_5=0
style_5=0
weight_5=0
shift_6=0
draw_6=2
color_6=6908265
style_6=0
weight_6=3
shift_7=0
draw_7=2
color_7=4800490
style_7=0
weight_7=3
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
color_15=1973790
style_15=0
weight_15=14
shift_16=0
draw_16=0
color_16=14772545
style_16=0
weight_16=10
shift_17=0
draw_17=0
color_17=14772545
style_17=0
weight_17=10
shift_18=0
draw_18=0
color_18=55295
style_18=0
weight_18=10
shift_19=0
draw_19=0
color_19=55295
style_19=0
weight_19=10
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
color_22=1973790
style_22=0
weight_22=12
shift_23=0
draw_23=0
color_23=14772545
style_23=0
weight_23=8
shift_24=0
draw_24=0
color_24=14772545
style_24=0
weight_24=8
shift_25=0
draw_25=0
color_25=55295
style_25=0
weight_25=8
shift_26=0
draw_26=0
color_26=55295
style_26=0
weight_26=8
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
color_29=1973790
style_29=0
weight_29=7
shift_30=0
draw_30=0
color_30=14772545
style_30=0
weight_30=3
shift_31=0
draw_31=0
color_31=14772545
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
ZigZag.Width=0
ZigZag.Color=16711680
Donchian.ShowChannel=0
Donchian.ShowCrossings=off* | first | all
Show123Projections=0
Signal.onReversal=0
Signal.onBreakout=1
Signal.onBreakout.123Only=1
Signal.onBreakout.Types=sound, alert
Sound.onChannelWidening=1
</inputs>
</expert>
style_2=2
style_3=2
weight_4=0
weight_5=0
color_6=4294967295
color_7=4294967295
show_data=1
</indicator>

</window>
</chart>
