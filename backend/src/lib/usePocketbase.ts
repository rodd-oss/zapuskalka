import PocketBase from "pocketbase";

const usePocketBase = () => new PocketBase("http://localhost:8090");

export default usePocketBase;