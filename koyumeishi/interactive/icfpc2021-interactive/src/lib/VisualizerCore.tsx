import {Input, Vertex, Output} from './models';
import {getPosFunc} from './utility';

enum SelectMode{
    Single,
    Multiple,
    Range,
    None,
    Move,
};


interface VisualizerCore {
    input: Input;
    outputSetter: Function;
    scoreDataSetter: Function;

    vertex: Vertex[];

    e: HTMLCanvasElement;
    ctx: CanvasRenderingContext2D;

    convertPosCanvToOrig: Function;
    convertPosOrigToCanv: Function;

    mode: SelectMode;
    selectStart: [number, number];
    selectEnd: [number, number];
}

const initialize = (
    input: Input,
    initialOutput: Output,
    outputSetter: Function,
    scoreDataSetter: Function
    ) => {
    let e = document.getElementById("canvas") as HTMLCanvasElement;
    let ctx = e.getContext("2d") as CanvasRenderingContext2D;
    let [convertPosCanvToOrig, convertPosOrigToCanv] = getPosFunc(input);
    
    let vertex: Vertex[] = initialOutput.vertices.map(p => {
        let res: Vertex = {
            pos: p,
            selected: false,
            fixed: false,
        };
        return res;
    });

    let res: VisualizerCore = {
        input,
        outputSetter,
        scoreDataSetter,
        
        vertex,

        e,
        ctx,
        convertPosCanvToOrig,
        convertPosOrigToCanv,

        mode: SelectMode.None,

        selectStart : [0,0],
        selectEnd: [0,0],
    };
    return res;
}


export {
    SelectMode, initialize
};
export type { VisualizerCore };
