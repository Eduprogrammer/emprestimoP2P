const { ethers } = require("hardhat");

async function main() {
  const [credor, devedor] = await ethers.getSigners();

  const EmprestimoP2p = await ethers.getContractFactory("emprestimoP2p");
  const contrato = await EmprestimoP2p.deploy();

  console.log("Contrato implantado em:", await contrato.getAddress());

  // 1. Credor inicia um empréstimo
  const valorPrincipal = ethers.parseEther("1");
  const taxaJuros = 100; // 10% (em permil no contrato, 100/1000 = 0.1)
  const prazoDias = 5;

  const tx1 = await contrato.connect(credor).iniciarEmprestimo(
    devedor.address,
    valorPrincipal,
    taxaJuros,
    prazoDias,
    { value: valorPrincipal }
  );
  await tx1.wait();
  console.log("📌 Empréstimo iniciado");

  // 2. Devedor saca o empréstimo
  const tx2 = await contrato.connect(devedor).sacarEmprestimo(0);
  await tx2.wait();
  console.log("💸 Empréstimo sacado pelo devedor");

  // 3. Devedor paga o empréstimo
  const verificaStatusEmprestimo = await contrato.verificaStatusEmprestimo(0);

  // --- Adicione estes logs para depuração ---
  console.log("Valor esperado pelo contrato (valorDevidoDoContrato):", ethers.formatEther(verificaStatusEmprestimo));
  // Neste momento, o valor que você está enviando é o mesmo que o contrato espera,
  // a menos que haja um bug no próprio contrato ou no cálculo.
  // O valor que você está enviando é o próprio valorDevidoDoContrato.
  console.log("Valor que o devedor vai tentar pagar:", ethers.formatEther(verificaStatusEmprestimo));
  // --- Fim dos logs ---

  const tx3 = await contrato.connect(devedor).pagarEmprestimo(0, {
    value: verificaStatusEmprestimo,
  });
  await tx3.wait();
  console.log("✅ Empréstimo pago pelo devedor");

  // 4. Credor saca o reembolso
  const tx4 = await contrato.connect(credor).sacarReembolso(0);
  await tx4.wait();
  console.log("💰 Reembolso sacado pelo credor");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("Erro:", error);
    process.exit(1);
  });