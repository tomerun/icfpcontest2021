import {Input} from './models';


const getPosFunc = (input: Input) => {
    const e = document.getElementById("canvas") as HTMLCanvasElement;
    
    let l = Math.min(
        input.hole.map(x => x[0]).reduce((a,b) => Math.min(a,b)),
        input.figure.vertices.map(x => x[0]).reduce((a,b) => Math.min(a,b)),
    );
    let r = Math.max(
        input.hole.map(x => x[0]).reduce((a,b) => Math.max(a,b)),
        input.figure.vertices.map(x => x[0]).reduce((a,b) => Math.max(a,b)),
    );
    let t = Math.min(
        input.hole.map(x => x[1]).reduce((a,b) => Math.min(a,b)),
        input.figure.vertices.map(x => x[1]).reduce((a,b) => Math.min(a,b)),
    );
    let b = Math.max(
        input.hole.map(x => x[1]).reduce((a,b) => Math.max(a,b)),
        input.figure.vertices.map(x => x[1]).reduce((a,b) => Math.max(a,b)),
    );
    
    const margin = 100;
    const offsetX = l;
    const offsetY = t;
    const canvasWidth = e.width - 2*margin;
    const canvasHeight = e.height - 2*margin;
    const objWidth = r-l;
    const objHeight = b-t;
    
    const ratio = Math.max(
        canvasWidth / Number(objWidth),
        canvasHeight / Number(objHeight),
    );
    
    const convertPosCanvToOrig = (x: number, y: number): [number, number] => {
        return [
            Math.round((x-margin) / ratio) + offsetX,
            Math.round((y-margin) / ratio) + offsetY,
        ];
    };
    
    const convertPosOrigToCanv = (x: number, y: number): [number, number] => {
        return [
            (x-offsetX) * ratio + margin,
            (y-offsetY) * ratio + margin,
        ];
    };
    
    return [convertPosCanvToOrig, convertPosOrigToCanv];
};

const getDist = (a: [number, number], b: [number, number]): number => {
    const dx = a[0] - b[0];
    const dy = a[1] - b[1];
    return Number(dx*dx + dy*dy);
};

const getSafeRange = (x: number, eps: number) :[number, number]  => {
    const k: number = Number(1000000);
    const ub: number = (k + eps) * x;
    const lb: number = (k - eps) * x;
    return [lb, ub];
};

export {
    getPosFunc,
    getDist,
    getSafeRange,
};