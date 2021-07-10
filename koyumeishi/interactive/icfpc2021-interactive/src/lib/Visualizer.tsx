import { useEffect, useRef } from 'react';
import {selector, useRecoilValue, useSetRecoilState} from 'recoil';
import {Button, Row} from 'react-bootstrap';

import {Input, Output, Vertex, VertexToOutput} from './models';
import {inputState, outputState} from './TextArea';
import {getDist, getSafeRange} from './utility';
import {VisualizerCore, SelectMode, initialize} from './VisualizerCore';
import {scoreData, calcScore} from './Score';
import {adjust} from './physicModel';

const inputData = selector({
    key: 'inputData',
    get: ({get}) => {
        let res = JSON.parse(get(inputState)) as Input;
        return res;
    },
});

const Visualizer = () => {
    const myref = useRef(null);
    const input = useRecoilValue(inputData);
    const outputSetter = useSetRecoilState(outputState);
    const scoreDataSetter = useSetRecoilState(scoreData);
    
    let initialOutput: Output = {vertices: [...input.figure.vertices]};

    const adjustButtonOnClick = () => {
        vis.vertex = adjust(vis.input, vis.vertex);
        render();
    };

    useEffect(() => {
        startVisualize(
            input,
            initialOutput,
            outputSetter,
            scoreDataSetter);
    });
    return (
        <>
            <Row className="mycanvas">
                <canvas id="canvas" width="600" height="600"></canvas>
            </Row>
            <Row>
                <Button onClick={adjustButtonOnClick}>
                    Adjust
                </Button>
            </Row>
        </>
    );
};

let vis: VisualizerCore;

const startVisualize = (
    input: Input,
    initialOutput: Output,
    outputSetter: any,
    scoreDataSetter: any) => {
    vis = initialize(
        input,
        initialOutput,
        outputSetter,
        scoreDataSetter);
    outputSetter(
        JSON.stringify(initialOutput)
    );
    scoreDataSetter(
        calcScore(vis.input, vis.vertex)
    );
    setHandler();
    render();
};


const clear = () => {
    vis.ctx.clearRect(0, 0, 600, 600);
}

const drawInput = () => {
    const {input, ctx, convertPosOrigToCanv} = vis;

    for (let i = 0; i < input.hole.length; i++) {
        const h = input.hole[i];
        const j = i == 0 ? input.hole.length - 1 : i - 1;
        const h_prev = input.hole[j];
        const p = convertPosOrigToCanv(h[0], h[1]);
        const q = convertPosOrigToCanv(h_prev[0], h_prev[1]);
        if (i == 0) ctx.moveTo(q[0], q[1]);
        ctx.lineTo(p[0], p[1]);
    }
    ctx.lineWidth = 1;
    ctx.fillStyle = "hsl(198, 14%, 73%)";
    ctx.fill();

    ctx.lineWidth = 2;
    ctx.fillStyle = "hsla(199, 18%, 40%)";
    ctx.strokeStyle = "hsla(199, 18%, 40%)";
    const rad = 2;
    for (let i = 0; i < input.hole.length; i++) {
        const h = input.hole[i];
        const p = convertPosOrigToCanv(h[0], h[1]);

        ctx.beginPath();
        ctx.arc(p[0], p[1], rad, 0, Math.PI * 2);
        ctx.stroke();
        ctx.fill();
    }
};

const drawOutput = () => {
    const {input, vertex, outputSetter, ctx, convertPosOrigToCanv} = vis;
    
    const setBasicStroke = () => {
        ctx.lineWidth = 1;
        ctx.strokeStyle = "hsl(28, 0%, 27%)";
    };
    const setShortStroke = (r: number) => {
        ctx.lineWidth = Math.min(5, 3 + Math.abs(r - 1) * 3);
        ctx.strokeStyle = "hsl(271, 73%, 59%)";
    };
    const setLongStroke = (r: number) => {
        ctx.lineWidth = Math.min(6, 3 + Math.abs(r - 1) * 3);
        ctx.strokeStyle = "hsl(360, 73%, 59%)";
    };
    input.figure.edges.forEach(v => {
        const [i,j] = v;
        const p = convertPosOrigToCanv(vertex[i].pos[0], vertex[i].pos[1]);
        const q = convertPosOrigToCanv(vertex[j].pos[0], vertex[j].pos[1]);
        
        const d0 = getDist(input.figure.vertices[i], input.figure.vertices[j]);
        const r = getSafeRange( d0, input.epsilon );
        const d = getDist(vertex[i].pos, vertex[j].pos);
        const k = Number(1000000);

        if(d*k < r[0]){
            // console.log(`short edge ${i}-${j}`);
            setShortStroke(d/d0);
        }else if(d*k > r[1]){
            // console.log(`long edge ${i}-${j}`);
            setLongStroke(d/d0);
        }else{
            setBasicStroke();
        }
        
        ctx.beginPath();
        ctx.moveTo(p[0], p[1]);
        ctx.lineTo(q[0], q[1]);
        ctx.stroke();
    });
    
    ctx.lineWidth = 2;
    const rad = 4;
    vertex.forEach((v, i) => {
        ctx.strokeStyle = "hsl(251, 69%, 34%)";
        ctx.fillStyle = "hsl(251, 69%, 34%)";
        ctx.beginPath();
        const q = convertPosOrigToCanv(v.pos[0], v.pos[1]);
        ctx.arc(q[0], q[1], rad, 0, Math.PI * 2);
        ctx.stroke();
        ctx.fill();
        
        if(v.fixed){
            ctx.fillStyle = "hsla(351, 69%, 64%, 100%)";
            ctx.beginPath();
            ctx.arc(q[0], q[1], rad, 0, Math.PI * 2);
            ctx.stroke();
            ctx.fill();
        }
        
        if(v.selected){
            ctx.fillStyle = "hsla(251, 69%, 64%, 60%)";
            ctx.beginPath();
            ctx.arc(q[0], q[1], rad*2, 0, Math.PI * 2);
            ctx.stroke();
            ctx.fill();
        }
        
    });
    
    ctx.fillStyle = "hsla(291, 46%, 43%, 80%)";
    if(vis.mode === SelectMode.Range){
        const p = convertPosOrigToCanv(vis.selectStart[0], vis.selectStart[1]);
        const q = convertPosOrigToCanv(vis.selectEnd[0], vis.selectEnd[1]);
        ctx.fillRect(
            Math.min(p[0], q[0]),
            Math.min(p[1], q[1]),
            Math.abs(p[0] - q[0]),
            Math.abs(p[1] - q[1]),
        );
    }
}
    
const render = () => {
    clear();
    drawInput();
    drawOutput();
}
    
const selectRect = (p0: [number, number], p1: [number, number]) => {
    const l = Math.min(p0[0], p1[0]);
    const r = Math.max(p0[0], p1[0]);
    const t = Math.min(p0[1], p1[1]);
    const b = Math.max(p0[1], p1[1]);
    
    vis.vertex = vis.vertex.map(v => {
        if(v.pos[0] < l || v.pos[0] > r || v.pos[1] < t || v.pos[1] > b){
            return {
                ...v,
                selected: false,
            }
        }else{
            return {
                ...v,
                selected: true,
            }
        }
    });
}

const addSelect = (p0: [number, number], p1: [number, number]) => {
    const l = Math.min(p0[0], p1[0]);
    const r = Math.max(p0[0], p1[0]);
    const t = Math.min(p0[1], p1[1]);
    const b = Math.max(p0[1], p1[1]);
    
    let cnt = 0;
    vis.vertex = vis.vertex.map(v => {
        if(v.pos[0] < l || v.pos[0] > r || v.pos[1] < t || v.pos[1] > b){
            return v;
        }else{
            cnt++;
            return {
                ...v,
                selected: true,
            }
        }
    });
    return cnt;
}

const trySelect = (p0: [number, number], p1: [number, number]) => {
    const l = Math.min(p0[0], p1[0]);
    const r = Math.max(p0[0], p1[0]);
    const t = Math.min(p0[1], p1[1]);
    const b = Math.max(p0[1], p1[1]);
    
    let res: number[] = [];
    vis.vertex.forEach((v,i) => {
        if(v.pos[0] < l || v.pos[0] > r || v.pos[1] < t || v.pos[1] > b){
        }else{
            res.push(i);
        }
    });
    return res;
}

const setHandler = () => {
    vis.e.onmousedown = (me: MouseEvent)=>{
        me.preventDefault();
        me.stopPropagation();
        const x = me.offsetX;
        const y = me.offsetY;
        const margin = 8;

        const c = vis.convertPosCanvToOrig(x, y);
        const s = vis.convertPosCanvToOrig(x-margin, y-margin);
        const t = vis.convertPosCanvToOrig(x+margin, y+margin);
        
        if(me.button == 2){
            let v = trySelect(s,t);
            v.forEach(i => {
                vis.vertex[i].fixed = !vis.vertex[i].fixed;
            });
            render();
            return;
        }
        
        if(me.shiftKey){
            // rect select
            vis.mode = SelectMode.Range;
            vis.selectStart = {...c};
            vis.selectEnd = {...c};
        }else if(me.ctrlKey){
            // multi select
            vis.mode = SelectMode.Multiple;
            addSelect(s, t);
        }else{
            if(vis.mode === SelectMode.None){
                if(addSelect(s, t) > 0){
                    vis.mode = SelectMode.Move;
                    vis.selectStart = {...c};
                    vis.selectEnd = {...c};
                }
            }else{
                let v = trySelect(s,t);
                if(v.length > 0 && vis.vertex[v[0]].selected){
                    vis.mode = SelectMode.Move;
                    vis.selectStart = {...c};
                    vis.selectEnd = {...c};
                }else if(v.length > 0){
                    selectRect(s, t); 
                    vis.mode = SelectMode.Move;
                    vis.selectStart = {...c};
                    vis.selectEnd = {...c};
                }else{
                    vis.mode = SelectMode.None;
                    vis.vertex = vis.vertex.map(v => {
                        return {...v, selected: false};
                    });
                }
            }
        }
        render();
    };

    vis.e.onmousemove = (me: MouseEvent) => {
        me.preventDefault();
        me.stopPropagation();
        const x = me.offsetX;
        const y = me.offsetY;
        const margin = 8;

        const c = vis.convertPosCanvToOrig(x, y);
        const s = vis.convertPosCanvToOrig(x-margin, y-margin);
        const t = vis.convertPosCanvToOrig(x+margin, y+margin);
        if(me.buttons == 0){
            return;
        }
        if(me.shiftKey){
            // rect select
            if(vis.mode === SelectMode.Range){
                vis.selectEnd = c;
                selectRect(vis.selectStart, vis.selectEnd);
            }
        }else if(me.ctrlKey){
            if(vis.mode === SelectMode.Multiple){
                addSelect(s, t);
            }
        }else{
            if(vis.mode === SelectMode.Move){
                vis.selectEnd = {...c};
                const dx = vis.selectEnd[0] - vis.selectStart[0];
                const dy = vis.selectEnd[1] - vis.selectStart[1];
                vis.selectStart = vis.selectEnd;
                vis.vertex = vis.vertex.map(v => {
                    if(v.fixed) return v;
                    if(v.selected === false) return v;
                    return {
                        ...v,
                        pos: [v.pos[0]+dx, v.pos[1]+dy],
                    };
                })
                vis.outputSetter(
                    JSON.stringify(VertexToOutput(vis.vertex))
                );
                vis.scoreDataSetter(
                    calcScore(vis.input, vis.vertex)
                );
            }
        }
        
        render();
    };
    
    vis.e.onmouseup = (me: MouseEvent) => {
        me.preventDefault();
        me.stopPropagation();
        if(me.button != 0){
            return;
        }
        if(me.shiftKey){
            // rect select
            if(vis.mode === SelectMode.Range){
                selectRect(vis.selectStart, vis.selectEnd);
                vis.mode = SelectMode.Multiple;
            }
        }else if(me.ctrlKey){
            if(vis.mode === SelectMode.Multiple){
            }
        }else{
            if(vis.mode === SelectMode.None){
            }else{
            }
        }
        
        render();
    };
    
}



export {Visualizer};
