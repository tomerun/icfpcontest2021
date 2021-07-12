type Points = [number, number][];

interface Figure {
    edges: [number, number][],
    vertices: Points,
};

export interface Input {
    hole: Points,
    figure: Figure,
    epsilon: number,
    bonuses: Bonuse[],
};

export interface Bonuse {
    bonus: string,
    problem: number,
    position: [number, number],
};

export interface Output {
    vertices: Points,
};

export interface Vertex {
    pos: [number, number];
    selected: boolean;
    fixed: boolean;
};

export const VertexToOutput = (vertex: Vertex[]) => {
    let res: Output = {
        vertices: vertex.map(v => v.pos),
    };
    return res;
};

