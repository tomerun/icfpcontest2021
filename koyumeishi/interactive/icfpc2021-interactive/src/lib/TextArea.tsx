import React, { useState } from 'react';
import { atom, useRecoilState, useRecoilValue } from 'recoil';
import {Input} from './models';
import {Row, Col} from 'react-bootstrap';

interface Props {
    input: Input,
};

const inputState = atom({
    key: 'inputState',
    default: '{"bonuses":[{"bonus":"GLOBALIST","problem":35,"position":[62,46]},{"bonus":"WALLHACK","problem":50,"position":[77,68]},{"bonus":"BREAK_A_LEG","problem":38,"position":[23,68]}],"hole":[[45,80],[35,95],[5,95],[35,50],[5,5],[35,5],[95,95],[65,95],[55,80]],"epsilon":150000,"figure":{"edges":[[2,5],[5,4],[4,1],[1,0],[0,8],[8,3],[3,7],[7,11],[11,13],[13,12],[12,18],[18,19],[19,14],[14,15],[15,17],[17,16],[16,10],[10,6],[6,2],[8,12],[7,9],[9,3],[8,9],[9,12],[13,9],[9,11],[4,8],[12,14],[5,10],[10,15]],"vertices":[[20,30],[20,40],[30,95],[40,15],[40,35],[40,65],[40,95],[45,5],[45,25],[50,15],[50,70],[55,5],[55,25],[60,15],[60,35],[60,65],[60,95],[70,95],[80,30],[80,40]]}}',
});

const initialOutputState = atom({
    key: 'initialOutputState',
    default: "",
});

const outputState = atom({
    key: 'outputState',
    default: '',
});

const InputArea: React.FC<{}> = () => {
    const [inputText, setInputState] = useRecoilState(inputState);
    return (
        <Col>
            <Row>
                Input Json
            </Row>
            <Row>
                <textarea
                    className="textarea"
                    onChange={(e) => {
                        setInputState(e.target.value);
                    }}
                    defaultValue={inputText} />
            </Row>
        </Col>
    );
};

const InitialOutputArea = () => {
    const [initialOutput, setInitialOutput] = useRecoilState(initialOutputState);
    return (
        <Col>
            <Row>
                Initial Output
            </Row>
            <Row>
                <textarea 
                className="textarea"
                onChange={(e)=>{
                setInitialOutput(e.target.value);
                }}
                defaultValue=""
                />
            </Row>
        </Col>
    );
};

const OutputArea: React.FC<{}> = () => {
    const text = useRecoilValue(outputState);
    return (
            <Col>
            <Row>
                Output JSON
            </Row>
            <Row>
                <textarea
                className="textarea"
                readOnly={true}
                defaultValue={text} />
            </Row>
            </Col>
    );
};

export {InputArea, InitialOutputArea, OutputArea, outputState, inputState, initialOutputState};
