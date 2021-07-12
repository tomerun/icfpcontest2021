"use strict";
const problem = document.getElementById("problem")
const solution = document.getElementById("solution")
const order = document.getElementById("order")
const start = document.getElementById("start")
const canvas = document.getElementById("canvas")
const margin = 10

start.onclick = (event) => {
	show()
}

function show() {
	const hole = JSON.parse(problem.value).hole
	const vertices = JSON.parse(solution.value).vertices
	const edges = JSON.parse(problem.value).figure.edges
	const max_x = hole.reduce((a, p)=> {
		return Math.max(a, p[0])
	}, 10)
	const max_y = hole.reduce((a, p)=> {
		return Math.max(a, p[1])
	}, 10)
	const drawScale = (canvas.width - margin * 2) / Math.max(max_x, max_y)
	const ctx = canvas.getContext('2d'); 
	ctx.fillStyle = '#CCCCCC'
	ctx.fillRect(0, 0, canvas.width, canvas.height)
	ctx.strokeStyle = 'black'
	ctx.fillStyle = 'white'
	const margin_scaled = margin / drawScale
	ctx.scale(drawScale, drawScale)
	ctx.translate(margin_scaled, margin_scaled)
	ctx.lineWidth = 1.0 / drawScale
	ctx.beginPath()
	ctx.moveTo(hole[hole.length - 1][0], hole[hole.length - 1][1])
	hole.forEach((p) => {
		ctx.lineTo(p[0], p[1])
	})
	ctx.closePath()
	ctx.stroke()
	ctx.fill()

	ctx.strokeStyle = '#888888'
	ctx.beginPath()
	for (let i = 10; i < max_x; i += 10) {
		ctx.moveTo(i, 0)
		ctx.lineTo(i, max_y)
	}
	for (let i = 10; i < max_y; i += 10) {
		ctx.moveTo(0, i)
		ctx.lineTo(max_x, i)
	}
	ctx.stroke()

	ctx.strokeStyle = 'red'
	ctx.beginPath()
	edges.forEach((e) => {
		const v1 = vertices[e[0]]	
		const v2 = vertices[e[1]]	
		ctx.moveTo(v1[0], v1[1])
		ctx.lineTo(v2[0], v2[1])
	})
	ctx.stroke()

	if (order.value) {
		ctx.fillStyle = 'black'
		ctx.font = `${drawScale * 0.2}px monospace`
		const order_vs = JSON.parse(order.value)
		for (let i = 0; i < order_vs.length; i++) {
			ctx.fillText(i.toString(), vertices[order_vs[i]][0], vertices[order_vs[i]][1])
		}
	}

	ctx.resetTransform()
}
