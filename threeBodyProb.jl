#!/usr/bin/env julia
using Plots, Random, Printf

function initCondGen()
    m=rand(1:1500,3)./10 #3 random masses between 0.1 and 150 solar masses
    rad=m.^0.8 #3 radii based on masses in solar units
    m=m.*2e30 #convert to SI kg
    rad=rad.*7e8 #convert to SI m
    pos1=rand(-35:35,2) #random initial coordinates x & y for first body, AU
    function genPos2(pos1)
        accept2=false
        while accept2==false
            pos2=rand(-35:35,2) #random initial coordinates for second body, AU
            dist21=sqrt((pos1[1]-pos2[1])^2+(pos1[2]-pos2[1])^2)
            if (dist21*1.5e11)>(rad[1]+rad[2]) #they aren't touching
                accept2=true
                return pos2
            end
        end
    end
    pos2=genPos2(pos1)
    function genPos3(pos1,pos2)
        accept3=false
        while accept3==false
            pos3=rand(-35:35,2) #random initial coordinates for third body, AU
            dist31=sqrt((pos1[1]-pos3[1])^2+(pos1[2]-pos3[1])^2)
            dist32=sqrt((pos2[1]-pos3[1])^2+(pos2[2]-pos3[1])^2)
            if (dist31*1.5e11)>(rad[1]+rad[3]) && (dist32*1.5e11)>(rad[2]+rad[3]) #3rd isn't touching either
                accept3=true
                return pos3
            end
        end
    end
    pos3=genPos3(pos1,pos2)
    pos=[pos1[1],pos1[2],pos2[1],pos2[2],pos3[1],pos3[2]].*1.5e11 #convert accepted positions to SI, m
    v=rand(-7e3:7e3,6) #random x & y velocities with mag between -10 & 10 km/s, totally arbitrary...
    #r=[x1,y1,x2,y2,x3,y3,v1x,v1y,v2x,v2y,v3x,v3y]
    r=[pos[1],pos[2],pos[3],pos[4],pos[5],pos[6],v[1],v[2],v[3],v[4],v[5],v[6]]
    open("initCond.txt","w") do f #save initial conditions to file in folder where script is run
        write(f,"m1=$(m[1]/2e30) m2=$(m[2]/2e30) m3=$(m[3]/2e30) (solar masses)\nv1x=$(v[1]/1e3) v1y=$(v[2]/1e3) v2x=$(v[3]/1e3) v2y=$(v[4]/1e3) v3x=$(v[5]/1e3) v3y=$(v[6]/1e3) (km/s)\nx1=$(pos1[1]) y1=$(pos1[2]) x2=$(pos2[1]) y2=$(pos2[2]) x3=$(pos3[1]) y3=$(pos3[2]) (AU from center)")
    end
    return r, rad, m
end

function dR(r,m)
    G=6.67408313131313e-11# Nm^2/kg^2
    M1,M2,M3=m[1],m[2],m[3]
    x1,x2,x3=r[1],r[3],r[5]
    y1,y2,y3=r[2],r[4],r[6]

    c1,c2,c3=G*M1,G*M2,G*M3
    r1_2=sqrt((x1-x2)^2+(y1-y2)^2) #distance from 1->2
    r1_3=sqrt((x1-x3)^2+(y1-y3)^2) #distance from 1->3
    r2_3=sqrt((x2-x3)^2+(y2-y3)^2) #distance from 2->3

    v1X,v2X,v3X=r[7],r[9],r[11]
    v1Y,v2Y,v3Y=r[8],r[10],r[12]

    dx1=-(c2*(x1-x2)/(r1_2^3))-(c3*(x1-x3)/(r1_3^3)) #d^2x/dt^2 for 1 (2 interactions)
    dx2=-(c1*(x2-x1)/(r1_2^3))-(c3*(x2-x3)/(r2_3^3)) #d^2x/dt^2 for 2
    dx3=-(c1*(x3-x1)/(r1_3^3))-(c2*(x3-x2)/(r2_3^3)) #d^2x/dt^2 for 3
    dy1=-(c2*(y1-y2)/(r1_2^3))-(c3*(y1-y3)/(r1_3^3)) #d^2y/dt^2 for 1
    dy2=-(c1*(y2-y1)/(r1_2^3))-(c3*(y2-y3)/(r2_3^3)) #d^2y/dt^2 for 2
    dy3=-(c1*(y3-y1)/(r1_3^3))-(c2*(y3-y2)/(r2_3^3)) #d^2y/dt^2 for 3

    return [v1X,v1Y,v2X,v2Y,v3X,v3Y,dx1,dy1,dx2,dy2,dx3,dy3]
end

function gen3Body(stopCond=[10,100],numSteps=10000) #default stop conditions of 10 yrs and 100 AU sep
    tStop=stopCond[1]*365*24*3600 #convert to SI s
    sepStop=stopCond[2]*1.5e11 #convert to SI m
    stop=false
    currentT=0
    t=range(0,stop=tStop,length=(numSteps+1)) #+1 because I don't want 0 to count
    stepSize=tStop/numSteps
    x1=zeros(length(t))
    y1=zeros(length(t))
    x2=zeros(length(t))
    y2=zeros(length(t))
    x3=zeros(length(t))
    y3=zeros(length(t))
    r,rad,m=initCondGen()
    min12=rad[1]+rad[2]
    min13=rad[1]+rad[3]
    min23=rad[2]+rad[3]
    i=1
    stopT=maximum(t)
    while stop==false
        if currentT==stopT || currentT>stopT #in case of rounding error or something
            stop=true
        elseif i>numSteps #inf loop failsafe
            stop=true
            println("error: shouldn't have gotten here")
        else
            x1[i]=r[1]
            y1[i]=r[2]
            x2[i]=r[3]
            y2[i]=r[4]
            x3[i]=r[5]
            y3[i]=r[6]

            k1=stepSize*dR(r,m)
            k2=stepSize*dR(r.+0.5.*k1,m)
            k3=stepSize*dR(r.+0.5.*k2,m)
            k4=stepSize*dR(r.+k3,m)
            r+=(k1.+2.0*k2.+2.0.*k3.+k4)./6

            sep12=sqrt((x1[i]-x2[i])^2+(y1[i]-y2[i])^2)
            sep13=sqrt((x1[i]-x3[i])^2+(y1[i]-y3[i])^2)
            sep23=sqrt((x3[i]-x2[i])^2+(y3[i]-y2[i])^2)
            if sep12<min12 || sep13<min13 || sep23<min23 || sep12>sepStop || sep13>sepStop || sep23>sepStop
                stop=true #stop if collision happens or body is ejected
                t=range(0,stop=currentT,length=i) #t should match pos vectors
                x1=x1[1:i] #don't want trailing zeros
                y1=y1[1:i]
                x2=x2[1:i]
                y2=y2[1:i]
                x3=x3[1:i]
                y3=y3[1:i]
            end
            i+=1
            currentT+=stepSize
        end
    end
    return [x1,y1,x2,y2,x3,y3], t, m, rad
end

function getInteresting3Body(minTime=0) #in years
    yearSec=365*24*3600
    interesting=false
    i=1
    while interesting==false
        plotData,t,m,rad=gen3Body([15,100],15000)
        if (maximum(t)/yearSec)>minTime
            println(maximum(t)/yearSec)
            return plotData,t,m,rad
            interesting=true
        elseif i>20 #computationally expensive so don't want to go forever
            interesting=true
            return plotData,t,m,rad
        end
        i+=1
    end
end

function getLims(pos,padding)
    x=[pos[1],pos[3],pos[5]]
    xMin=minimum(x)
    xMax=maximum(x)
    dx=xMax-xMin
    y=[pos[2],pos[4],pos[6]]
    yMin=minimum(y)
    yMax=maximum(y)
    dy=yMax-yMin
    if dx>dy
        #use x for square
        xlims=[xMin-padding,xMax+padding]
        ylims=[yMin-padding,yMin+dx+padding]
    else
        #use y for square
        xlims=[xMin-padding,xMin+dy+padding]
        ylims=[yMin-padding,yMax+padding]
    end
    return xlims,ylims
end

function getColors(m,c)
    #c=[:red,:yellow,:orange] #red=biggest yellow=smallest
    maxM=maximum(m)
    minM=minimum(m)
    colors=[:blue,:blue,:blue] #testing
    if m[1]==maxM
        colors[1]=c[1]
        if m[2]==minM
            colors[2]=c[3]
            colors[3]=c[2]
        else
            colors[3]=c[3]
            colors[2]=c[2]
        end
    elseif m[2]==maxM
        colors[2]=c[1]
        if m[1]==minM
            colors[1]=c[3]
            colors[3]=c[2]
        else
            colors[3]=c[3]
            colors[1]=c[2]
        end
    else
        colors[3]=c[1]
        if m[1]==minM
            colors[1]=c[3]
            colors[2]=c[2]
        else
            colors[2]=c[3]
            colors[1]=c[2]
        end
    end
    return colors
end

function makeCircleVals(r,center=[0,0])
    xOffset=center[1]
    yOffset=center[2]
    xVals=[r*cos(i)+xOffset for i=0:(pi/64):(2*pi)]
    yVals=[r*sin(i)+yOffset for i=0:(pi/64):(2*pi)]
    return xVals,yVals
end

plotData,t,m,rad=getInteresting3Body(9)
c=[:red,:orange,:yellow]
colors=getColors(m,c)
#adding fake stars
starsX=[]
starsY=[]
for i=1:100
    num=rand(-35e11:35e11,2)
    push!(starsX,num[1])
    push!(starsY,num[2])
end

threeBodyAnim=@animate for i=1:length(t)
    gr(legendfontcolor = plot_color(:white)) #plot arg broken right now in Julia
    print("$(@sprintf("%.2f",i/length(t)*100)) % complete\r") #output percent tracker
    pos=[plotData[1][i],plotData[2][i],plotData[3][i],plotData[4][i],plotData[5][i],plotData[6][i]] #current pos
    limx,limy=getLims(pos./1.5e11,5) #convert to AU, 5 AU padding
    plot(plotData[1][1:i]./1.5e11,plotData[2][1:i]./1.5e11,label="",linecolor=colors[1])
    plot!(plotData[3][1:i]./1.5e11,plotData[4][1:i]./1.5e11,label="",linecolor=colors[2])
    plot!(plotData[5][1:i]./1.5e11,plotData[6][1:i]./1.5e11,label="",linecolor=colors[3])
    scatter!(starsX,starsY,markercolor=:white,markersize=:100,label="") #fake background stars
    star1=makeCircleVals(rad[1],[plotData[1][i],plotData[2][i]])
    star2=makeCircleVals(rad[2],[plotData[3][i],plotData[4][i]])
    star3=makeCircleVals(rad[3],[plotData[5][i],plotData[6][i]])
    plot!(star1[1]./1.5e11,star1[2]./1.5e11,label="$(@sprintf("%.1f", m[1]./2e30))",color=colors[1],fill=true)
    plot!(star2[1]./1.5e11,star2[2]./1.5e11,label="$(@sprintf("%.1f", m[2]./2e30))",color=colors[2],fill=true)
    plot!(star3[1]./1.5e11,star3[2]./1.5e11,label="$(@sprintf("%.1f", m[3]./2e30))",color=colors[3],fill=true)
    plot!(background_color=:black,background_color_legend=:transparent,background_color_outside=:white,aspect_ratio=:equal,legendtitlefontcolor=:white) #legendfontcolor=:white
    plot!(xlabel="x: AU",ylabel="y: AU",title="Random 3 Body Problem\nt: $(@sprintf("%0.2f",t[i]/365/24/3600)) yrs after start",
        legend=:best,xaxis=("x: AU",(limx[1],limx[2]),font(22,"Courier")),yaxis=("y: AU",(limy[1],limy[2]),font(22,"Courier")),
        grid=false,titlefont=font(42,"Courier"),size=(2048,2048),legendfontsize=22,legendtitle="Mass (in solar masses)",legendtitlefontsize=26)
    end every 25
#with these conditions takes ~12 sec/% (not including saving below) or ~20 min total time
gif(threeBodyAnim,"3Body_fps30.gif",fps=30)
