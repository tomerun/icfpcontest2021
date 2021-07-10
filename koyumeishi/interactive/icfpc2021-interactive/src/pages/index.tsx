import Head from 'next/head'
import React from 'react'
import styles from '../styles/Home.module.css'
import {InputArea, OutputArea} from '../lib/TextArea'
import { Visualizer } from '../lib/Visualizer'
import { Infomation } from '../lib/Infomation'
import {Container, Row, Col} from 'react-bootstrap';

export default function Home() {
  return (
    <div className={styles.container}>
      <Head>
        <title>ICFPC 2021 - Interactive Visualizer</title>
        <link rel="icon" href="/favicon.ico" />
      </Head>

      <Container>
        <Row>
          <Col>
            <Visualizer />
          </Col>
          <Col>
            <Infomation />
          </Col>
        </Row>
        <Row>
          <Col>
            <InputArea />
          </Col>
          <Col>
            <OutputArea />
          </Col>
        </Row>
      </Container>

    </div>
  )
}
