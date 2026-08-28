import { startLayer } from "./layer";
import "./styles.css";

const canvas = document.querySelector("canvas");
if (!canvas) throw new Error("Canvas missing");
startLayer(canvas);
