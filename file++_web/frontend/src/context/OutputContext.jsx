import React, { createContext, useContext, useState } from 'react';

const OutputContext = createContext();

export function OutputProvider({ children }) {
  const [outputs, setOutputs] = useState([]);

  const addOutput = ({ blob, name, toolSource }) => {
    const id = Date.now().toString();
    const url = URL.createObjectURL(blob);
    const item = {
      id,
      name,
      blob,
      url,
      size: (blob.size / 1024).toFixed(1) + ' KB',
      toolSource: toolSource || 'Dönüştürücü',
      createdAt: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
    };
    setOutputs((prev) => [item, ...prev]);
  };

  const removeOutput = (id) => {
    setOutputs((prev) => prev.filter((o) => o.id !== id));
  };

  const clearOutputs = () => {
    setOutputs([]);
  };

  return (
    <OutputContext.Provider value={{ outputs, addOutput, removeOutput, clearOutputs }}>
      {children}
    </OutputContext.Provider>
  );
}

export const useOutputs = () => useContext(OutputContext);